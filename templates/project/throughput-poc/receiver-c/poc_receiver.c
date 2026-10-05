/*#############################################################################
FILE NAME   : poc_receiver.c
DESCRIPTION : 처리량 PoC C 기준선 수신기 — 프레임 재조립, 시퀀스 갭 검사, 지연 분위수, CPU·RSS 요약
#############################################################################*/

#include <errno.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/resource.h>
#include <sys/socket.h>
#include <unistd.h>

#include "../common/poc_wire.h"

#define RECV_BUF_BYTES     (4 * 1024 * 1024)
#define SOCK_RCVBUF_BYTES  (4 * 1024 * 1024)
#define CONNECT_RETRIES    100
#define CONNECT_BACKOFF_NS 50000000ull       /* 50ms */
#define CLOCK_SANITY_NS    1000000000ull     /* HELLO 수신 시각 차가 1초 안이면 같은 시계로 본다 */

typedef struct ReceiverState
{
    uint64_t hist[POC_HIST_BUCKETS];
    uint64_t received;
    uint64_t expected;            /* END 가 알려준 송신 총 건수 */
    uint64_t next_seq;
    uint64_t gaps;                /* 갭 발생 횟수 */
    uint64_t gap_msgs;            /* 갭으로 건너뛴 메시지 수 */
    uint64_t out_of_order;
    uint64_t start_ns;            /* 송신 측 HELLO 시작 시각 */
    uint64_t first_data_ns;
    uint64_t last_data_ns;
    int64_t  clock_offset_ns;     /* HELLO 수신 시각 - 송신 시작 시각 */
    int      latency_ok;
    int      saw_hello;
    int      saw_end;
    uint64_t sec_mark_ns;         /* 초당 처리량 집계 */
    uint64_t sec_count;
} ReceiverState;

/*=============================================================================
FUNCTION    : ConnectWithRetry
DESCRIPTION : 송신기가 listen 할 때까지 재시도하며 연결한다
PARAMETERS  : const char *host - IPv4 주소
              int port - 포트
RETURNED    : 연결 fd, 실패 시 -1
=============================================================================*/
static int ConnectWithRetry(const char *host, int port)
{
    struct sockaddr_in addr;
    struct timespec    backoff = { 0, (long)CONNECT_BACKOFF_NS };
    int                rcvbuf = SOCK_RCVBUF_BYTES;
    int                tries;

    memset(&addr, 0, sizeof(addr));
    addr.sin_family = AF_INET;
    addr.sin_port   = htons((uint16_t)port);
    if (inet_pton(AF_INET, host, &addr.sin_addr) != 1)
        return -1;

    for (tries = 0; tries < CONNECT_RETRIES; tries++)
    {
        int fd = socket(AF_INET, SOCK_STREAM, 0);

        if (fd < 0)
            return -1;
        setsockopt(fd, SOL_SOCKET, SO_RCVBUF, &rcvbuf, sizeof(rcvbuf));
        if (connect(fd, (struct sockaddr *)&addr, sizeof(addr)) == 0)
            return fd;
        close(fd);
        nanosleep(&backoff, NULL);
    }
    return -1;
}

/*=============================================================================
FUNCTION    : HandleFrame
DESCRIPTION : 완성된 프레임 하나를 해석해 통계에 반영한다
PARAMETERS  : ReceiverState *st - 상태
              const uint8_t *payload - payload
              uint32_t len - payload 길이
              uint64_t now_ns - 이 recv 묶음의 수신 시각
=============================================================================*/
static void HandleFrame(ReceiverState *st, const uint8_t *payload, uint32_t len, uint64_t now_ns)
{
    uint32_t kind;
    uint64_t field_a;
    uint64_t field_b;

    if (len < POC_MIN_PAYLOAD)
        return;
    kind    = PocGetLe32(payload);
    field_a = PocGetLe64(payload + 8);
    field_b = PocGetLe64(payload + 16);

    if (kind == POC_KIND_HELLO)
    {
        st->saw_hello       = 1;
        st->start_ns        = field_a;
        st->clock_offset_ns = (int64_t)(now_ns - field_a);
        st->latency_ok      = st->clock_offset_ns >= 0
                           && (uint64_t)st->clock_offset_ns < CLOCK_SANITY_NS;
        return;
    }
    if (kind == POC_KIND_END)
    {
        st->saw_end  = 1;
        st->expected = field_a;
        return;
    }
    if (kind != POC_KIND_DATA)
        return;

    if (st->received == 0)
        st->first_data_ns = now_ns;
    st->last_data_ns = now_ns;
    st->received++;
    st->sec_count++;

    if (field_a > st->next_seq)
    {
        st->gaps++;
        st->gap_msgs += field_a - st->next_seq;
    }
    else if (field_a < st->next_seq)
        st->out_of_order++;
    if (field_a >= st->next_seq)
        st->next_seq = field_a + 1;

    if (st->latency_ok)
    {
        uint64_t sched_abs = st->start_ns + field_b;
        uint64_t lat_ns    = now_ns > sched_abs ? now_ns - sched_abs : 0;

        st->hist[PocHistIndex(lat_ns / 1000ull)]++;
    }
}

/*=============================================================================
FUNCTION    : ReceiveLoop
DESCRIPTION : 소켓에서 읽어 프레임 단위로 재조립한다. 남은 조각은 버퍼 앞으로 옮긴다
PARAMETERS  : int fd - 연결 소켓
              ReceiverState *st - 상태
RETURNED    : 0 정상 종료(END 또는 EOF), -1 오류
=============================================================================*/
static int ReceiveLoop(int fd, ReceiverState *st)
{
    uint8_t *buf;
    size_t   filled = 0;

    buf = malloc(RECV_BUF_BYTES);
    if (buf == NULL)
        return -1;

    /* HOTPATH — recv 한 번에 완성 프레임을 모두 처리하고 남은 조각만 앞으로 옮긴다 */
    while (!st->saw_end)
    {
        ssize_t  got;
        size_t   offset = 0;
        uint64_t now_ns;

        got = recv(fd, buf + filled, RECV_BUF_BYTES - filled, 0);
        if (got < 0 && errno == EINTR)
            continue;
        if (got <= 0)
            break;
        now_ns  = PocNowNs();
        filled += (size_t)got;

        while (filled - offset >= POC_FRAME_HEADER)
        {
            uint32_t len = PocGetBe32(buf + offset);

            if (len > POC_MAX_PAYLOAD)
            {
                fprintf(stderr, "[poc_receiver] frame too large: %u\n", len);
                free(buf);
                return -1;
            }
            if (filled - offset < POC_FRAME_HEADER + len)
                break;
            HandleFrame(st, buf + offset + POC_FRAME_HEADER, len, now_ns);
            offset += POC_FRAME_HEADER + len;
        }
        if (offset > 0)
        {
            memmove(buf, buf + offset, filled - offset);
            filled -= offset;
        }

        if (st->sec_mark_ns == 0)
            st->sec_mark_ns = now_ns;
        if (now_ns - st->sec_mark_ns >= 1000000000ull)
        {
            fprintf(stderr, "[poc_receiver] %llu msg/s\n", (unsigned long long)st->sec_count);
            st->sec_count   = 0;
            st->sec_mark_ns = now_ns;
        }
    }
    free(buf);
    return 0;
}

/*=============================================================================
FUNCTION    : MaxRssMb
DESCRIPTION : 프로세스 최대 RSS 를 MB 로 돌려준다 (macOS 는 바이트, Linux 는 KB 단위)
RETURNED    : 최대 RSS (MB)
=============================================================================*/
static double MaxRssMb(const struct rusage *usage)
{
#if defined(__APPLE__)
    return (double)usage->ru_maxrss / (1024.0 * 1024.0);
#else
    return (double)usage->ru_maxrss / 1024.0;
#endif
}

static double TimevalSec(const struct timeval *tv)
{
    return (double)tv->tv_sec + (double)tv->tv_usec / 1e6;
}

/*=============================================================================
FUNCTION    : WriteSummary
DESCRIPTION : 수신 요약을 JSON 으로 쓴다 (receiver.mjs 와 같은 키)
PARAMETERS  : const ReceiverState *st - 상태
              double wall_sec - 연결부터 종료까지 벽시계 시간
              const char *path - 출력 경로 (NULL 이면 stdout)
=============================================================================*/
static void WriteSummary(const ReceiverState *st, double wall_sec, const char *path)
{
    struct rusage usage;
    FILE         *out = stdout;
    double        active_sec;
    double        cpu_sec;
    uint64_t      lat_total = 0;
    int           ii;

    getrusage(RUSAGE_SELF, &usage);
    cpu_sec    = TimevalSec(&usage.ru_utime) + TimevalSec(&usage.ru_stime);
    active_sec = (double)(st->last_data_ns - st->first_data_ns) / 1e9;
    for (ii = 0; ii < POC_HIST_BUCKETS; ii++)
        lat_total += st->hist[ii];

    if (path != NULL)
    {
        out = fopen(path, "w");
        if (out == NULL)
        {
            perror("[poc_receiver] summary");
            return;
        }
    }
    fprintf(out,
            "{\"role\":\"receiver\",\"receiver\":\"c\",\"received\":%llu,\"expected\":%llu,"
            "\"sawEnd\":%s,\"gaps\":%llu,\"gapMessages\":%llu,\"outOfOrder\":%llu,"
            "\"activeSec\":%.3f,\"throughput\":%.0f,\"latencyMeasured\":%s,\"clockOffsetUs\":%lld,"
            "\"p50Us\":%llu,\"p99Us\":%llu,\"p999Us\":%llu,\"maxUs\":%llu,"
            "\"maxRssMb\":%.1f,\"cpuPercent\":%.1f,\"wallSec\":%.3f}\n",
            (unsigned long long)st->received, (unsigned long long)st->expected,
            st->saw_end ? "true" : "false",
            (unsigned long long)st->gaps, (unsigned long long)st->gap_msgs,
            (unsigned long long)st->out_of_order,
            active_sec, active_sec > 0 ? (double)st->received / active_sec : 0.0,
            st->latency_ok ? "true" : "false", (long long)(st->clock_offset_ns / 1000),
            (unsigned long long)PocHistQuantile(st->hist, lat_total, 0.50),
            (unsigned long long)PocHistQuantile(st->hist, lat_total, 0.99),
            (unsigned long long)PocHistQuantile(st->hist, lat_total, 0.999),
            (unsigned long long)PocHistQuantile(st->hist, lat_total, 1.0),
            MaxRssMb(&usage), wall_sec > 0 ? cpu_sec / wall_sec * 100.0 : 0.0, wall_sec);
    if (out != stdout)
        fclose(out);
}

int main(int argc, char **argv)
{
    static ReceiverState state;
    const char          *host = "127.0.0.1";
    const char          *summary_path = NULL;
    int                  port = 47100;
    int                  opt;
    int                  fd;
    int                  rc;
    uint64_t             begin_ns;

    while ((opt = getopt(argc, argv, "h:p:o:")) != -1)
    {
        switch (opt)
        {
        case 'h': host         = optarg;       break;
        case 'p': port         = atoi(optarg); break;
        case 'o': summary_path = optarg;       break;
        default:
            fprintf(stderr, "usage: %s [-h host] [-p port] [-o summary.json]\n", argv[0]);
            return 2;
        }
    }

    fd = ConnectWithRetry(host, port);
    if (fd < 0)
    {
        fprintf(stderr, "[poc_receiver] connect failed %s:%d\n", host, port);
        return 1;
    }
    begin_ns = PocNowNs();
    rc = ReceiveLoop(fd, &state);
    close(fd);
    WriteSummary(&state, (double)(PocNowNs() - begin_ns) / 1e9, summary_path);
    return rc == 0 ? 0 : 1;
}
