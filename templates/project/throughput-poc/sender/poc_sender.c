/*#############################################################################
FILE NAME   : poc_sender.c
DESCRIPTION : 처리량 PoC 송신 시뮬레이터 — 개방 루프 목표 레이트로 길이 prefix 고정 크기 메시지를 TCP 송신
#############################################################################*/

#include <errno.h>
#include <netinet/in.h>
#include <netinet/tcp.h>
#include <arpa/inet.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <unistd.h>

#include "../common/poc_wire.h"

/*-----------------------------------------------------------------------------
기본값과 상한
MAX_BATCH_FRAMES — 일정보다 뒤처졌을 때 한 번의 write 로 묶어 보낼 최대 프레임 수.
GRACE_SEC        — 수신 측이 느려 일정이 밀릴 때 duration 뒤로 더 기다리는 최대 시간.
-----------------------------------------------------------------------------*/
#define DEFAULT_PORT      47100
#define DEFAULT_RATE      10000ull
#define DEFAULT_MSG_SIZE  64u
#define DEFAULT_DURATION  10u
#define MAX_BATCH_FRAMES  1024u
#define GRACE_SEC         30u
#define SEND_BUF_BYTES    (4 * 1024 * 1024)
#define MAX_RATE          100000000ull     /* 1억 건/초 — 일정 계산 오버플로 방지 상한 */
#define MAX_DURATION      86400u

typedef struct SenderConfig
{
    const char *bind_addr;
    int         port;
    uint64_t    rate;            /* 목표 메시지/초 */
    uint32_t    msg_size;        /* payload 바이트 */
    uint32_t    duration_sec;
    const char *summary_path;    /* JSON 요약 경로 (NULL 이면 stdout) */
} SenderConfig;

typedef struct SenderStats
{
    uint64_t sent;
    uint64_t target;
    uint64_t writes;
    uint64_t batched_writes;     /* 프레임 2개 이상을 묶은 write 횟수 */
    uint64_t max_lag_ns;         /* 예정 시각 대비 실제 송신 시작의 최대 지연 */
    uint64_t elapsed_ns;
    int      timed_out;          /* GRACE_SEC 초과로 송신을 멈췄는가 */
} SenderStats;

/*=============================================================================
FUNCTION    : PrintUsage
DESCRIPTION : 사용법을 stderr 로 출력한다
PARAMETERS  : const char *prog - 실행 파일 이름
=============================================================================*/
static void PrintUsage(const char *prog)
{
    fprintf(stderr,
            "usage: %s [-b addr] [-p port] [-r msgs_per_sec] [-s msg_bytes] [-d seconds] [-o summary.json]\n",
            prog);
}

/*=============================================================================
FUNCTION    : ParseArgs
DESCRIPTION : 명령행 인자를 설정 구조체로 해석한다
PARAMETERS  : int argc, char **argv - 명령행
              SenderConfig *cfg - 결과
RETURNED    : 0 성공, -1 잘못된 인자
=============================================================================*/
static int ParseArgs(int argc, char **argv, SenderConfig *cfg)
{
    int opt;

    cfg->bind_addr    = "127.0.0.1";
    cfg->port         = DEFAULT_PORT;
    cfg->rate         = DEFAULT_RATE;
    cfg->msg_size     = DEFAULT_MSG_SIZE;
    cfg->duration_sec = DEFAULT_DURATION;
    cfg->summary_path = NULL;

    while ((opt = getopt(argc, argv, "b:p:r:s:d:o:")) != -1)
    {
        switch (opt)
        {
        case 'b': cfg->bind_addr    = optarg;                           break;
        case 'p': cfg->port         = atoi(optarg);                     break;
        case 'r': cfg->rate         = strtoull(optarg, NULL, 10);       break;
        case 's': cfg->msg_size     = (uint32_t)strtoul(optarg, NULL, 10); break;
        case 'd': cfg->duration_sec = (uint32_t)strtoul(optarg, NULL, 10); break;
        case 'o': cfg->summary_path = optarg;                           break;
        default:  return -1;
        }
    }
    if (cfg->port <= 0 || cfg->port > 65535 || cfg->rate == 0 || cfg->rate > MAX_RATE
        || cfg->duration_sec == 0 || cfg->duration_sec > MAX_DURATION)
        return -1;
    if (cfg->msg_size < POC_MIN_PAYLOAD || cfg->msg_size > POC_MAX_PAYLOAD)
    {
        fprintf(stderr, "[poc_sender] msg size must be %u..%u\n", POC_MIN_PAYLOAD, POC_MAX_PAYLOAD);
        return -1;
    }
    return 0;
}

/*=============================================================================
FUNCTION    : AcceptOneClient
DESCRIPTION : 지정 주소에서 listen 하고 클라이언트 하나를 받는다
PARAMETERS  : const SenderConfig *cfg - 설정
RETURNED    : 연결 fd, 실패 시 -1
=============================================================================*/
static int AcceptOneClient(const SenderConfig *cfg)
{
    struct sockaddr_in addr;
    int                listen_fd;
    int                conn_fd;
    int                one = 1;
    int                sndbuf = SEND_BUF_BYTES;

    listen_fd = socket(AF_INET, SOCK_STREAM, 0);
    if (listen_fd < 0)
        return -1;
    setsockopt(listen_fd, SOL_SOCKET, SO_REUSEADDR, &one, sizeof(one));

    memset(&addr, 0, sizeof(addr));
    addr.sin_family = AF_INET;
    addr.sin_port   = htons((uint16_t)cfg->port);
    if (inet_pton(AF_INET, cfg->bind_addr, &addr.sin_addr) != 1
        || bind(listen_fd, (struct sockaddr *)&addr, sizeof(addr)) != 0
        || listen(listen_fd, 1) != 0)
    {
        perror("[poc_sender] listen");
        close(listen_fd);
        return -1;
    }
    fprintf(stderr, "[poc_sender] listening %s:%d\n", cfg->bind_addr, cfg->port);

    do
        conn_fd = accept(listen_fd, NULL, NULL);
    while (conn_fd < 0 && errno == EINTR);
    close(listen_fd);
    if (conn_fd < 0)
        return -1;

    /* 묶음 송신이 목적이므로 Nagle 지연은 끈다 — 묶음은 애플리케이션이 직접 만든다 */
    setsockopt(conn_fd, IPPROTO_TCP, TCP_NODELAY, &one, sizeof(one));
    setsockopt(conn_fd, SOL_SOCKET, SO_SNDBUF, &sndbuf, sizeof(sndbuf));
    return conn_fd;
}

/*=============================================================================
FUNCTION    : WriteAll
DESCRIPTION : 버퍼 전체를 쓴다. 블로킹 소켓이므로 수신 측이 느리면 여기서 기다린다
PARAMETERS  : int fd - 소켓
              const uint8_t *buf - 데이터
              size_t len - 길이
RETURNED    : 0 성공, -1 실패(연결 끊김 등)
=============================================================================*/
static int WriteAll(int fd, const uint8_t *buf, size_t len)
{
    ssize_t written;

    while (len > 0)
    {
        written = write(fd, buf, len);
        if (written < 0)
        {
            if (errno == EINTR)
                continue;
            return -1;
        }
        buf += written;
        len -= (size_t)written;
    }
    return 0;
}

/*=============================================================================
FUNCTION    : SleepNs
DESCRIPTION : 지정 ns 만큼 잔다 (EINTR 이면 남은 시간만큼 다시)
PARAMETERS  : uint64_t wait_ns - 대기 시간
=============================================================================*/
static void SleepNs(uint64_t wait_ns)
{
    struct timespec req;
    struct timespec rem;

    req.tv_sec  = (time_t)(wait_ns / 1000000000ull);
    req.tv_nsec = (long)(wait_ns % 1000000000ull);
    while (nanosleep(&req, &rem) != 0 && errno == EINTR)
        req = rem;
}

/*=============================================================================
FUNCTION    : ScheduledNs
DESCRIPTION : 메시지 seq 의 예정 송신 시각(시작 기준 ns) = seq / rate 초.
              seq * 1e9 가 넘치지 않도록 몫과 나머지로 나눠 계산한다
PARAMETERS  : uint64_t seq - 시퀀스 번호
              uint64_t rate - 목표 메시지/초
RETURNED    : 시작 기준 상대 ns
=============================================================================*/
static uint64_t ScheduledNs(uint64_t seq, uint64_t rate)
{
    return seq / rate * 1000000000ull + seq % rate * 1000000000ull / rate;
}

/*=============================================================================
FUNCTION    : RunSchedule
DESCRIPTION : 개방 루프 일정대로 송신한다. 메시지 n 의 예정 시각은 start + n/rate 이다.
              뒤처지면 기다리지 않고 밀린 만큼 묶어서 한 번에 쓴다(수신 측 속도가 일정을 바꾸지 않음).
PARAMETERS  : int fd - 연결 소켓
              const SenderConfig *cfg - 설정
              SenderStats *stats - 결과
RETURNED    : 0 성공, -1 송신 실패
=============================================================================*/
static int RunSchedule(int fd, const SenderConfig *cfg, SenderStats *stats)
{
    const size_t frame_bytes = POC_FRAME_HEADER + cfg->msg_size;
    uint8_t     *batch;
    uint64_t     start_ns;
    uint64_t     deadline_ns;
    uint64_t     next_seq = 0;
    int          rc = 0;

    batch = calloc(MAX_BATCH_FRAMES, frame_bytes);
    if (batch == NULL)
        return -1;

    stats->target = cfg->rate * cfg->duration_sec;
    start_ns      = PocNowNs();
    deadline_ns   = start_ns + (uint64_t)(cfg->duration_sec + GRACE_SEC) * 1000000000ull;

    /*--- HELLO: 시작 시각을 알려 수신 측이 시계 공유 여부를 판정하게 한다 ---*/
    PocEncodeFrame(batch, cfg->msg_size, POC_KIND_HELLO, start_ns, 0);
    if (WriteAll(fd, batch, frame_bytes) != 0)
    {
        free(batch);
        return -1;
    }

    /* HOTPATH — 일정 계산과 묶음 인코딩. 루프 안에서 할당하지 않는다 */
    while (next_seq < stats->target)
    {
        uint64_t now_ns = PocNowNs();
        uint64_t rel_ns = now_ns - start_ns;
        uint64_t due    = rel_ns / 1000000000ull * cfg->rate
                        + (rel_ns % 1000000000ull) * cfg->rate / 1000000000ull + 1;
        uint64_t count;
        uint64_t sched_ns;
        uint64_t ii;

        if (now_ns > deadline_ns)
        {
            stats->timed_out = 1;
            break;
        }
        if (due > stats->target)
            due = stats->target;
        sched_ns = ScheduledNs(next_seq, cfg->rate);
        if (next_seq >= due)
        {
            if (sched_ns > rel_ns)
                SleepNs(sched_ns - rel_ns);
            continue;
        }
        if (rel_ns > sched_ns && rel_ns - sched_ns > stats->max_lag_ns)
            stats->max_lag_ns = rel_ns - sched_ns;

        /*--- 밀린 프레임을 묶어 한 번에 쓴다 ---*/
        count = due - next_seq;
        if (count > MAX_BATCH_FRAMES)
            count = MAX_BATCH_FRAMES;
        for (ii = 0; ii < count; ii++)
        {
            uint64_t seq = next_seq + ii;

            PocEncodeFrame(batch + ii * frame_bytes, cfg->msg_size, POC_KIND_DATA,
                           seq, ScheduledNs(seq, cfg->rate));
        }
        if (WriteAll(fd, batch, (size_t)count * frame_bytes) != 0)
        {
            rc = -1;
            break;
        }
        stats->writes++;
        if (count > 1)
            stats->batched_writes++;
        next_seq += count;
    }
    stats->sent = next_seq;

    /*--- END: 총 송신 건수를 알려 수신 측이 유실을 계산하게 한다 ---*/
    if (rc == 0)
    {
        memset(batch, 0, frame_bytes);
        PocEncodeFrame(batch, cfg->msg_size, POC_KIND_END, stats->sent, 0);
        rc = WriteAll(fd, batch, frame_bytes);
    }
    stats->elapsed_ns = PocNowNs() - start_ns;
    free(batch);
    return rc;
}

/*=============================================================================
FUNCTION    : WriteSummary
DESCRIPTION : 송신 요약을 JSON 으로 쓴다
PARAMETERS  : const SenderConfig *cfg - 설정
              const SenderStats *stats - 결과
=============================================================================*/
static void WriteSummary(const SenderConfig *cfg, const SenderStats *stats)
{
    FILE *out = stdout;

    if (cfg->summary_path != NULL)
    {
        out = fopen(cfg->summary_path, "w");
        if (out == NULL)
        {
            perror("[poc_sender] summary");
            return;
        }
    }
    fprintf(out,
            "{\"role\":\"sender\",\"targetRate\":%llu,\"msgSize\":%u,\"durationSec\":%u,"
            "\"target\":%llu,\"sent\":%llu,\"writes\":%llu,\"batchedWrites\":%llu,"
            "\"maxLagUs\":%llu,\"elapsedSec\":%.3f,\"timedOut\":%s}\n",
            (unsigned long long)cfg->rate, cfg->msg_size, cfg->duration_sec,
            (unsigned long long)stats->target, (unsigned long long)stats->sent,
            (unsigned long long)stats->writes, (unsigned long long)stats->batched_writes,
            (unsigned long long)(stats->max_lag_ns / 1000ull),
            (double)stats->elapsed_ns / 1e9, stats->timed_out ? "true" : "false");
    if (out != stdout)
        fclose(out);
}

int main(int argc, char **argv)
{
    SenderConfig cfg;
    SenderStats  stats;
    int          conn_fd;
    int          rc;

    if (ParseArgs(argc, argv, &cfg) != 0)
    {
        PrintUsage(argv[0]);
        return 2;
    }
    signal(SIGPIPE, SIG_IGN);
    memset(&stats, 0, sizeof(stats));

    conn_fd = AcceptOneClient(&cfg);
    if (conn_fd < 0)
        return 1;
    rc = RunSchedule(conn_fd, &cfg, &stats);
    shutdown(conn_fd, SHUT_WR);
    close(conn_fd);
    WriteSummary(&cfg, &stats);
    if (rc != 0)
        fprintf(stderr, "[poc_sender] send failed after %llu msgs\n", (unsigned long long)stats.sent);
    return rc == 0 ? 0 : 1;
}
