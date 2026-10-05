/*#############################################################################
FILE NAME   : log.c
DESCRIPTION : 운영 로그 모듈 구현 — key=value 한 줄 형식, 동기/비동기 출력, 폭주 억제, 재오픈
#############################################################################*/
/*
 * 동시성 설계
 *  - 락은 셋이고 한 번에 하나만 잡는다(중첩 없음): g_FloodLock(억제 표), g_RingLock(링버퍼).
 *    파일 쓰기는 락 없이 한다. 재오픈은 dup2()로 같은 fd 번호의 대상을 원자적으로 바꾼다.
 *  - 락을 잡은 채 I/O를 하지 않는다. 생산자는 락 밖에서 줄을 만들고 락 안에서는 복사만 한다.
 *  - 링버퍼가 가득 차면 생산자는 기다리지 않고 유실 수만 센다. 로거 스레드가 요약을 남긴다.
 *  - 리눅스 전용 API(gettid)는 GetThreadId 한 곳에 격리한다(D08).
 */
#if defined(__linux__)
#define _GNU_SOURCE
#endif

#include <errno.h>
#include <signal.h>
#include <stdarg.h>
#include <stdatomic.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#include <fcntl.h>
#include <pthread.h>
#include <unistd.h>
#include <sys/types.h>
#if defined(__linux__)
#include <sys/syscall.h>
#endif

#include "log.h"

#define LOG_HOST_MAX            64
#define LOG_PROC_MAX            32
#define LOG_TS_MAX              64
#define LOG_RING_DEFAULT_SLOTS  4096
#define LOG_BATCH_SLOTS         64      /* 로거 스레드가 한 번에 꺼내 쓰는 줄 수 */
#define LOG_FLUSH_INTERVAL_MS   200     /* 주기 flush 간격 */
#define LOG_FLOOD_TABLE_SIZE    512
#define LOG_FLOOD_PROBE_MAX     8
#define LOG_FILE_MODE           0640
#define LOG_TRUNC_MARK          "...\n"

typedef struct
{
    size_t      len;
    char        text[LOG_LINE_MAX];
} LogSlot;

typedef struct
{
    const char *file;           /* 호출 위치 키: __FILE__ 리터럴 + 줄 */
    int         line;
    const char *module;
    const char *func;
    LogLevel    level;
    time_t      window_start;
    unsigned    count;
    unsigned    suppressed;
} FloodEntry;

/* 레벨 검사 — 헤더의 매크로가 읽는다 */
_Atomic int g_LogMinLevel = LOG_LEVEL_INFO;

/* 설정·출력 대상 — LogInit/LogShutdown에서만 바꾼다 */
static int        g_LogFd                    = STDERR_FILENO;
static bool       g_IsOwnFd                  = false;
static bool       g_IsInitialized            = false;
static bool       g_UseUtc                   = false;
static long       g_UtcOffsetSec             = 0;     /* 크래시 줄용 — 초기화 시점 오프셋 */
static char       g_LogPath[LOG_PATH_MAX]    = "";
static char       g_HostName[LOG_HOST_MAX]   = "-";
static char       g_ProcName[LOG_PROC_MAX]   = "-";
static pid_t      g_Pid                      = 0;
static atomic_uint g_ForkGen                 = 0;     /* fork마다 증가 — 스레드 캐시 무효화 */
static bool       g_IsAtforkSet              = false;
static atomic_uint g_ConfigGen               = 0;     /* LogInit마다 증가 — 시각 캐시 무효화 */

static volatile sig_atomic_t g_ReopenRequested = 0;

/* 누적 통계 */
static atomic_uint_fast64_t g_DropTotal      = 0;
static atomic_uint_fast64_t g_DropPending    = 0;     /* 아직 요약하지 않은 유실 수 */
static atomic_uint_fast64_t g_SuppressTotal  = 0;
static atomic_uint_fast64_t g_WriteErrTotal  = 0;

/* 폭주 억제 */
static pthread_mutex_t g_FloodLock           = PTHREAD_MUTEX_INITIALIZER;
static FloodEntry      g_FloodTable[LOG_FLOOD_TABLE_SIZE];
static unsigned        g_FloodMax            = 0;
static unsigned        g_FloodWindowSec      = 0;

/* 비동기 링버퍼 */
static pthread_mutex_t g_RingLock            = PTHREAD_MUTEX_INITIALIZER;
static pthread_cond_t  g_RingCond            = PTHREAD_COND_INITIALIZER;
static pthread_cond_t  g_RingDrained         = PTHREAD_COND_INITIALIZER;
static LogSlot        *g_Ring                = NULL;
static size_t          g_RingCap             = 0;
static size_t          g_RingHead            = 0;
static size_t          g_RingCount           = 0;
static bool            g_IsWriting           = false;
static bool            g_IsStopping          = false;
static bool            g_IsWriterRunning     = false;
static pthread_t       g_Writer;
static char           *g_Batch               = NULL;

/* 스레드 지역 상태 */
static _Thread_local char     g_TxnId[LOG_TXN_ID_MAX] = "";
static _Thread_local long     g_TidCache              = -1;
static _Thread_local unsigned g_TidGen                = 0;
static _Thread_local time_t   g_TsCacheSec            = (time_t)-1;
static _Thread_local unsigned g_TsCacheGen            = 0;
static _Thread_local char     g_TsCachePrefix[LOG_TS_MAX] = "";
static _Thread_local char     g_TsCacheZone[8]        = "";

static const char *const g_LevelNames[] = { "TRACE", "DEBUG", "INFO", "WARN", "ERROR", "FATAL" };

/*-----------------------------------------------------------------------------
내부 유틸리티
-----------------------------------------------------------------------------*/
static const char *LevelName(LogLevel level)
{
    if (level < LOG_LEVEL_TRACE || level > LOG_LEVEL_FATAL) { return "-"; }
    return g_LevelNames[level];
}

static const char *BaseName(const char *path)
{
    const char *slash = strrchr(path, '/');

    return slash ? slash + 1 : path;
}

static void AtforkChild(void)
{
    g_Pid = getpid();
    atomic_fetch_add(&g_ForkGen, 1u);
}

/* 리눅스는 커널 tid, macOS는 pthread_threadid_np — 스레드별로 한 번만 구한다 */
static long GetThreadId(void)
{
    unsigned gen = atomic_load_explicit(&g_ForkGen, memory_order_relaxed);

    if (g_TidCache < 0 || g_TidGen != gen)
    {
#if defined(__linux__)
        g_TidCache = (long)syscall(SYS_gettid);
#elif defined(__APPLE__)
        uint64_t tid = 0;

        pthread_threadid_np(NULL, &tid);
        g_TidCache = (long)tid;
#else
        g_TidCache = (long)getpid();
#endif
        g_TidGen = gen;
    }
    return g_TidCache;
}

/* EINTR·부분 쓰기를 처리한다. 실패하면 -errno */
static int WriteAll(int fd, const char *buf, size_t len)
{
    while (len > 0)
    {
        ssize_t written = write(fd, buf, len);

        if (written < 0)
        {
            if (errno == EINTR) { continue; }
            return -errno;
        }
        buf += written;
        len -= (size_t)written;
    }
    return 0;
}

/* 디스크 풀 등으로 실패해도 서비스는 멈추지 않는다 — 세고 버린다 */
static void WriteOut(const char *buf, size_t len)
{
    if (WriteAll(g_LogFd, buf, len) < 0)
    {
        atomic_fetch_add(&g_WriteErrTotal, 1u);
    }
}

/*-----------------------------------------------------------------------------
시각 — µs 정밀도 ISO 8601. 로컬이면 +09:00 오프셋, UTC면 Z.
같은 초 안에서는 스레드별 캐시를 재사용해 localtime_r 호출을 줄인다.
-----------------------------------------------------------------------------*/
static int FormatTimestamp(char *buf, size_t size)
{
    struct timespec now;
    struct tm       tm_now;

    unsigned        gen = atomic_load_explicit(&g_ConfigGen, memory_order_relaxed);

    clock_gettime(CLOCK_REALTIME, &now);
    if (now.tv_sec != g_TsCacheSec || gen != g_TsCacheGen)
    {
        char zone[8] = "";

        if (g_UseUtc) { gmtime_r(&now.tv_sec, &tm_now); }
        else          { localtime_r(&now.tv_sec, &tm_now); }
        strftime(g_TsCachePrefix, sizeof(g_TsCachePrefix), "%Y-%m-%dT%H:%M:%S", &tm_now);
        if (g_UseUtc)
        {
            snprintf(g_TsCacheZone, sizeof(g_TsCacheZone), "Z");
        }
        else
        {
            strftime(zone, sizeof(zone), "%z", &tm_now);    /* +0900 → +09:00 */
            snprintf(g_TsCacheZone, sizeof(g_TsCacheZone), "%.3s:%.2s", zone, zone + 3);
        }
        g_TsCacheSec = now.tv_sec;
        g_TsCacheGen = gen;
    }
    return snprintf(buf, size, "%s.%06ld%s", g_TsCachePrefix,
                    (long)(now.tv_nsec / 1000), g_TsCacheZone);
}

/* 메시지 안의 제어 문자를 공백으로 바꾼다 — 가짜 줄 삽입(로그 인젝션) 방지 */
static void SanitizeText(char *text, size_t len)
{
    size_t ii;

    for (ii = 0; ii < len; ii++)
    {
        if ((unsigned char)text[ii] < 0x20 || text[ii] == 0x7f) { text[ii] = ' '; }
    }
}

/*=============================================================================
FUNCTION    : FormatLineV
DESCRIPTION : key=value 한 줄을 만든다. 넘치면 자르고 "...\n"으로 끝낸다.
RETURNED    : 줄 길이(개행 포함)
=============================================================================*/
static size_t FormatLineV(char *buf, LogLevel level, const char *module, const char *file,
                          int line, const char *func, const char *fmt, va_list ap)
    __attribute__((format(printf, 7, 0)));

static size_t FormatLineV(char *buf, LogLevel level, const char *module, const char *file,
                          int line, const char *func, const char *fmt, va_list ap)
{
    const size_t size    = LOG_LINE_MAX;
    char         ts[LOG_TS_MAX];
    const char  *txn     = g_TxnId[0] ? g_TxnId : "-";
    int          head    = 0;
    int          body    = 0;
    size_t       len     = 0;

    FormatTimestamp(ts, sizeof(ts));
    head = snprintf(buf, size,
                    "ts=%s host=%s proc=%s pid=%ld tid=%ld lvl=%s mod=%s file=%s fn=%s:%d txn=%s msg=",
                    ts, g_HostName, g_ProcName, (long)g_Pid, GetThreadId(), LevelName(level),
                    module ? module : "-", BaseName(file ? file : "-"), func ? func : "-",
                    line, txn);
    if (head < 0) { head = 0; }
    len = (size_t)head;
    if (len < size - 1)
    {
        body = vsnprintf(buf + len, size - 1 - len, fmt, ap);   /* 개행 자리 1바이트 남김 */
        if (body < 0) { body = 0; }
        if ((size_t)body >= size - 1 - len)
        {
            len = size - 1;
            SanitizeText(buf + head, len - (size_t)head);
            memcpy(buf + size - sizeof(LOG_TRUNC_MARK), LOG_TRUNC_MARK, sizeof(LOG_TRUNC_MARK));
            return size - 1;
        }
        SanitizeText(buf + len, (size_t)body);
        len += (size_t)body;
    }
    else
    {
        len = size - 2;
    }
    buf[len++] = '\n';
    buf[len]   = '\0';
    return len;
}

static size_t FormatLine(char *buf, LogLevel level, const char *module, const char *file,
                         int line, const char *func, const char *fmt, ...)
    __attribute__((format(printf, 7, 8)));

static size_t FormatLine(char *buf, LogLevel level, const char *module, const char *file,
                         int line, const char *func, const char *fmt, ...)
{
    va_list ap;
    size_t  len;

    va_start(ap, fmt);
    len = FormatLineV(buf, level, module, file, line, func, fmt, ap);
    va_end(ap);
    return len;
}

/*-----------------------------------------------------------------------------
폭주 억제 — 호출 위치(파일·줄)별로 창마다 최대 g_FloodMax건
-----------------------------------------------------------------------------*/
static time_t MonotonicSec(void)
{
    struct timespec now;

    clock_gettime(CLOCK_MONOTONIC, &now);
    return now.tv_sec;
}

static void EmitLine(LogLevel level, const char *buf, size_t len);

static void EmitFloodSummary(const FloodEntry *entry, unsigned suppressed)
{
    char   buf[LOG_LINE_MAX];
    size_t len;

    len = FormatLine(buf, LOG_LEVEL_WARN, entry->module, entry->file, entry->line, entry->func,
                     "log flood suppressed=%u window_sec=%u", suppressed, g_FloodWindowSec);
    EmitLine(LOG_LEVEL_WARN, buf, len);     /* 비동기 모드면 링으로 — 폭주 중에도 생산자가 블록되지 않게 */
}

/* 기록해도 되면 true. 창이 바뀌며 생략분이 있으면 *out_prev에 담는다 */
static bool FloodAllow(LogLevel level, const char *module, const char *file, int line,
                       const char *func, FloodEntry *out_prev, unsigned *out_suppressed)
{
    uintptr_t   hash    = ((uintptr_t)file >> 4) ^ ((uintptr_t)line * 2654435761u);
    FloodEntry *entry   = NULL;
    time_t      now     = MonotonicSec();
    bool        allow   = true;
    int         ii;

    *out_suppressed = 0;
    pthread_mutex_lock(&g_FloodLock);
    for (ii = 0; ii < LOG_FLOOD_PROBE_MAX; ii++)
    {
        FloodEntry *cand = &g_FloodTable[(hash + (uintptr_t)ii) % LOG_FLOOD_TABLE_SIZE];

        if (cand->file == file && cand->line == line) { entry = cand; break; }
        if (cand->file == NULL)
        {
            entry = cand;
            entry->file         = file;
            entry->line         = line;
            entry->module       = module;
            entry->func         = func;
            entry->level        = level;
            entry->window_start = now;
            break;
        }
    }
    if (entry != NULL)      /* 표가 가득 차면 억제하지 않는다 */
    {
        if (now - entry->window_start >= (time_t)g_FloodWindowSec)
        {
            if (entry->suppressed > 0)
            {
                *out_prev       = *entry;
                *out_suppressed = entry->suppressed;
            }
            entry->window_start = now;
            entry->count        = 0;
            entry->suppressed   = 0;
        }
        if (entry->count < g_FloodMax) { entry->count++; }
        else                           { entry->suppressed++; allow = false; }
    }
    pthread_mutex_unlock(&g_FloodLock);
    if (!allow) { atomic_fetch_add(&g_SuppressTotal, 1u); }
    return allow;
}

/* 종료 시 남은 생략분을 요약한다 */
static void FlushFloodSummaries(void)
{
    int ii;

    for (ii = 0; ii < LOG_FLOOD_TABLE_SIZE; ii++)
    {
        FloodEntry entry;

        pthread_mutex_lock(&g_FloodLock);
        entry = g_FloodTable[ii];
        g_FloodTable[ii].suppressed = 0;
        pthread_mutex_unlock(&g_FloodLock);
        if (entry.file != NULL && entry.suppressed > 0)
        {
            EmitFloodSummary(&entry, entry.suppressed);
        }
    }
}

/*-----------------------------------------------------------------------------
비동기 링버퍼
-----------------------------------------------------------------------------*/
static void ReportDrops(void)
{
    uint64_t dropped = atomic_exchange(&g_DropPending, 0u);
    char     buf[LOG_LINE_MAX];
    size_t   len;

    if (dropped == 0) { return; }
    len = FormatLine(buf, LOG_LEVEL_WARN, "log", __FILE__, __LINE__, __func__,
                     "log ring full dropped=%llu", (unsigned long long)dropped);
    WriteOut(buf, len);
}

/* 가득 차면 기다리지 않고 false */
static bool RingPush(const char *line, size_t len)
{
    bool pushed = false;
    bool wake   = false;

    pthread_mutex_lock(&g_RingLock);
    if (g_RingCount < g_RingCap)
    {
        LogSlot *slot = &g_Ring[(g_RingHead + g_RingCount) % g_RingCap];

        memcpy(slot->text, line, len);
        slot->len = len;
        g_RingCount++;
        pushed = true;
        wake   = (g_RingCount == LOG_BATCH_SLOTS);    /* 한 묶음이 차면 깨운다. 아니면 주기 flush */
    }
    pthread_mutex_unlock(&g_RingLock);
    if (wake) { pthread_cond_signal(&g_RingCond); }
    return pushed;
}

static void DeadlineAfterMs(struct timespec *deadline, long ms)
{
    clock_gettime(CLOCK_REALTIME, deadline);
    deadline->tv_sec  += ms / 1000;
    deadline->tv_nsec += (ms % 1000) * 1000000L;
    if (deadline->tv_nsec >= 1000000000L)
    {
        deadline->tv_sec  += 1;
        deadline->tv_nsec -= 1000000000L;
    }
}

static void *WriterMain(void *arg)
{
    (void)arg;
    for (;;)
    {
        size_t batch_len = 0;
        size_t taken     = 0;
        bool   is_done   = false;

        pthread_mutex_lock(&g_RingLock);
        if (g_RingCount == 0 && !g_IsStopping)
        {
            struct timespec deadline;

            DeadlineAfterMs(&deadline, LOG_FLUSH_INTERVAL_MS);
            pthread_cond_timedwait(&g_RingCond, &g_RingLock, &deadline);
        }
        while (g_RingCount > 0 && taken < LOG_BATCH_SLOTS)
        {
            const LogSlot *slot = &g_Ring[g_RingHead];

            memcpy(g_Batch + batch_len, slot->text, slot->len);
            batch_len  += slot->len;
            g_RingHead  = (g_RingHead + 1) % g_RingCap;
            g_RingCount--;
            taken++;
        }
        g_IsWriting = (batch_len > 0);
        is_done     = (g_RingCount == 0 && g_IsStopping && batch_len == 0);
        pthread_mutex_unlock(&g_RingLock);

        if (batch_len > 0) { WriteOut(g_Batch, batch_len); }   /* 락 밖에서 한 번에 쓴다 */
        ReportDrops();

        pthread_mutex_lock(&g_RingLock);
        g_IsWriting = false;
        if (g_RingCount == 0) { pthread_cond_broadcast(&g_RingDrained); }
        pthread_mutex_unlock(&g_RingLock);
        if (is_done) { break; }
    }
    return NULL;
}

static int StartWriter(size_t slots)
{
    int ret;

    g_RingCap = slots ? slots : LOG_RING_DEFAULT_SLOTS;
    g_Ring    = calloc(g_RingCap, sizeof(LogSlot));            /* 기동 시 한 번만 할당 */
    g_Batch   = malloc((size_t)LOG_BATCH_SLOTS * LOG_LINE_MAX);
    if (g_Ring == NULL || g_Batch == NULL)
    {
        free(g_Ring);
        free(g_Batch);
        g_Ring  = NULL;
        g_Batch = NULL;
        return -ENOMEM;
    }
    g_RingHead   = 0;
    g_RingCount  = 0;
    g_IsStopping = false;
    ret = pthread_create(&g_Writer, NULL, WriterMain, NULL);
    if (ret != 0)
    {
        free(g_Ring);
        free(g_Batch);
        g_Ring  = NULL;
        g_Batch = NULL;
        return -ret;
    }
    g_IsWriterRunning = true;
    return 0;
}

static void StopWriter(void)
{
    if (!g_IsWriterRunning) { return; }
    pthread_mutex_lock(&g_RingLock);
    g_IsStopping = true;
    pthread_mutex_unlock(&g_RingLock);
    pthread_cond_signal(&g_RingCond);
    pthread_join(g_Writer, NULL);
    g_IsWriterRunning = false;
    free(g_Ring);
    free(g_Batch);
    g_Ring    = NULL;
    g_Batch   = NULL;
    g_RingCap = 0;
}

/*-----------------------------------------------------------------------------
공개 함수
-----------------------------------------------------------------------------*/
static long CurrentUtcOffset(void)
{
    time_t    now = time(NULL);
    struct tm local_tm;
    struct tm utc_tm;
    long      diff;

    localtime_r(&now, &local_tm);
    gmtime_r(&now, &utc_tm);
    diff = (long)(local_tm.tm_hour - utc_tm.tm_hour) * 3600L
         + (long)(local_tm.tm_min - utc_tm.tm_min) * 60L;
    if (local_tm.tm_yday != utc_tm.tm_yday)     /* 날짜 경계 보정 */
    {
        bool is_ahead = (local_tm.tm_year > utc_tm.tm_year)
                     || (local_tm.tm_year == utc_tm.tm_year && local_tm.tm_yday > utc_tm.tm_yday);

        diff += is_ahead ? 86400L : -86400L;
    }
    return diff;
}

int LogInit(const LogConfig *cfg)
{
    int ret = 0;

    if (cfg == NULL || cfg->level < LOG_LEVEL_TRACE || cfg->level > LOG_LEVEL_OFF) { return -EINVAL; }
    if (cfg->flood_max > 0 && cfg->flood_window_sec == 0) { return -EINVAL; }
    if (g_IsInitialized) { return -EALREADY; }

    tzset();                                   /* localtime_r은 tzset을 보장하지 않는다 */
    g_UseUtc         = cfg->use_utc;
    g_UtcOffsetSec   = g_UseUtc ? 0 : CurrentUtcOffset();
    g_Pid            = getpid();
    g_FloodMax       = cfg->flood_max;
    g_FloodWindowSec = cfg->flood_window_sec;
    memset(g_FloodTable, 0, sizeof(g_FloodTable));
    atomic_store(&g_DropTotal, 0u);
    atomic_store(&g_DropPending, 0u);
    atomic_store(&g_SuppressTotal, 0u);
    atomic_store(&g_WriteErrTotal, 0u);
    if (gethostname(g_HostName, sizeof(g_HostName)) != 0) { snprintf(g_HostName, sizeof(g_HostName), "-"); }
    g_HostName[sizeof(g_HostName) - 1] = '\0';
    snprintf(g_ProcName, sizeof(g_ProcName), "%.*s", (int)(sizeof(g_ProcName) - 1),
             cfg->proc_name ? cfg->proc_name : "-");
    if (!g_IsAtforkSet && pthread_atfork(NULL, NULL, AtforkChild) == 0) { g_IsAtforkSet = true; }

    if (cfg->path != NULL)
    {
        if (strlen(cfg->path) >= sizeof(g_LogPath)) { return -ENAMETOOLONG; }
        snprintf(g_LogPath, sizeof(g_LogPath), "%.*s", (int)(sizeof(g_LogPath) - 1), cfg->path);
        g_LogFd = open(g_LogPath, O_WRONLY | O_CREAT | O_APPEND | O_CLOEXEC, LOG_FILE_MODE);
        if (g_LogFd < 0)
        {
            ret     = -errno;
            g_LogFd = STDERR_FILENO;
            return ret;
        }
        g_IsOwnFd = true;
    }
    if (cfg->async)
    {
        ret = StartWriter(cfg->ring_slots);
        if (ret < 0)
        {
            if (g_IsOwnFd) { close(g_LogFd); }
            g_LogFd   = STDERR_FILENO;
            g_IsOwnFd = false;
            return ret;
        }
    }
    atomic_fetch_add(&g_ConfigGen, 1u);
    atomic_store(&g_LogMinLevel, (int)cfg->level);
    g_IsInitialized = true;
    return 0;
}

void LogShutdown(void)
{
    if (!g_IsInitialized) { return; }
    StopWriter();                   /* 남은 줄을 모두 쓴 뒤 멈춘다 */
    FlushFloodSummaries();
    ReportDrops();
    if (g_IsOwnFd) { close(g_LogFd); }
    g_LogFd         = STDERR_FILENO;
    g_IsOwnFd       = false;
    g_LogPath[0]    = '\0';
    g_IsInitialized = false;
    atomic_store(&g_LogMinLevel, (int)LOG_LEVEL_INFO);
}

int LogReopen(void)
{
    int new_fd;
    int ret = 0;

    if (!g_IsOwnFd) { return 0; }
    new_fd = open(g_LogPath, O_WRONLY | O_CREAT | O_APPEND | O_CLOEXEC, LOG_FILE_MODE);
    if (new_fd < 0) { return -errno; }               /* 실패하면 기존 파일에 계속 쓴다 */
    while (dup2(new_fd, g_LogFd) < 0)               /* 같은 fd 번호를 원자적으로 새 파일로 */
    {
        if (errno != EINTR) { ret = -errno; break; }
    }
    close(new_fd);
    if (ret == 0)
    {
        /* dup2는 O_CLOEXEC를 넘기지 않는다 — 다시 건다 */
        int flags = fcntl(g_LogFd, F_GETFD);

        if (flags >= 0) { fcntl(g_LogFd, F_SETFD, flags | FD_CLOEXEC); }
    }
    return ret;
}

void LogRequestReopen(void)
{
    g_ReopenRequested = 1;
}

int LogReopenIfRequested(void)
{
    if (!g_ReopenRequested) { return 0; }
    g_ReopenRequested = 0;
    return LogReopen();
}

void LogSetLevel(LogLevel level)
{
    if (level < LOG_LEVEL_TRACE || level > LOG_LEVEL_OFF) { return; }
    atomic_store(&g_LogMinLevel, (int)level);
}

LogLevel LogGetLevel(void)
{
    return (LogLevel)atomic_load(&g_LogMinLevel);
}

void LogSetTxnId(const char *txn_id)
{
    size_t ii;

    if (txn_id == NULL) { g_TxnId[0] = '\0'; return; }
    for (ii = 0; ii < LOG_TXN_ID_MAX - 1 && txn_id[ii] != '\0'; ii++)
    {
        unsigned char ch = (unsigned char)txn_id[ii];

        g_TxnId[ii] = (ch <= 0x20 || ch == 0x7f || ch == '=') ? '_' : (char)ch;
    }
    g_TxnId[ii] = '\0';
}

void LogClearTxnId(void)
{
    g_TxnId[0] = '\0';
}

const char *LogGetTxnId(void)
{
    return g_TxnId;
}

void LogFlush(void)
{
    if (!g_IsWriterRunning) { return; }
    pthread_mutex_lock(&g_RingLock);
    pthread_cond_signal(&g_RingCond);
    while (g_RingCount > 0 || g_IsWriting)
    {
        pthread_cond_wait(&g_RingDrained, &g_RingLock);
    }
    pthread_mutex_unlock(&g_RingLock);
}

void LogGetStats(LogStats *out)
{
    if (out == NULL) { return; }
    out->dropped      = (uint64_t)atomic_load(&g_DropTotal);
    out->suppressed   = (uint64_t)atomic_load(&g_SuppressTotal);
    out->write_errors = (uint64_t)atomic_load(&g_WriteErrTotal);
}

/*-----------------------------------------------------------------------------
출력 분배 — 비동기 모드는 링으로(가득 차면 유실 집계), 동기 모드와 FATAL은 바로 쓴다
-----------------------------------------------------------------------------*/
static void EmitLine(LogLevel level, const char *buf, size_t len)
{
    if (g_IsWriterRunning && level != LOG_LEVEL_FATAL)
    {
        if (!RingPush(buf, len))
        {
            atomic_fetch_add(&g_DropTotal, 1u);
            atomic_fetch_add(&g_DropPending, 1u);
        }
        return;
    }
    if (level == LOG_LEVEL_FATAL) { LogFlush(); }    /* 앞선 줄을 먼저 내보낸 뒤 동기로 쓴다 */
    WriteOut(buf, len);
}

void LogWrite(LogLevel level, const char *module, const char *file, int line,
              const char *func, const char *fmt, ...)
{
    char       buf[LOG_LINE_MAX];
    FloodEntry prev;
    unsigned   prev_suppressed = 0;
    size_t     len;
    va_list    ap;

    if (fmt == NULL) { return; }
    if (g_FloodMax > 0
        && !FloodAllow(level, module, file, line, func, &prev, &prev_suppressed))
    {
        return;
    }
    if (prev_suppressed > 0) { EmitFloodSummary(&prev, prev_suppressed); }

    va_start(ap, fmt);
    len = FormatLineV(buf, level, module, file, line, func, fmt, ap);
    va_end(ap);

    EmitLine(level, buf, len);
}

/*-----------------------------------------------------------------------------
크래시 줄 — async-signal-safe 함수만 쓴다(snprintf·localtime_r 금지).
날짜는 초기화 때 구한 UTC 오프셋으로 직접 계산한다.
-----------------------------------------------------------------------------*/
static char *PutUnsigned(char *pos, unsigned long value, int width)
{
    char digits[24];
    int  count = 0;

    do
    {
        digits[count++] = (char)('0' + (value % 10));
        value /= 10;
    } while (value > 0 && count < (int)sizeof(digits));
    while (count < width) { digits[count++] = '0'; }
    while (count > 0) { *pos++ = digits[--count]; }
    return pos;
}

static char *PutText(char *pos, const char *end, const char *text)
{
    while (*text != '\0' && pos < end) { *pos++ = *text++; }
    return pos;
}

/* 1970-01-01 기준 일수 → 연·월·일 (그레고리력, 정수 연산만) */
static void CivilFromDays(long days, long *year, unsigned *month, unsigned *day)
{
    long     era;
    unsigned doe;
    unsigned yoe;
    unsigned doy;
    unsigned mp;

    days += 719468;
    era   = (days >= 0 ? days : days - 146096) / 146097;
    doe   = (unsigned)(days - era * 146097);
    yoe   = (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365;
    doy   = doe - (365 * yoe + yoe / 4 - yoe / 100);
    mp    = (5 * doy + 2) / 153;
    *day   = doy - (153 * mp + 2) / 5 + 1;
    *month = mp < 10 ? mp + 3 : mp - 9;
    *year  = (long)yoe + era * 400 + (*month <= 2 ? 1 : 0);
}

void LogCrashNote(int signo)
{
    char            buf[LOG_LINE_MAX];
    char           *pos       = buf;
    const char     *end       = buf + sizeof(buf) - 1;
    struct timespec now;
    long            local_sec;
    long            days;
    long            secs;
    long            year;
    unsigned        month;
    unsigned        day;
    long            offset    = g_UtcOffsetSec;

    clock_gettime(CLOCK_REALTIME, &now);
    local_sec = (long)now.tv_sec + offset;
    days      = local_sec / 86400L;
    secs      = local_sec % 86400L;
    if (secs < 0) { secs += 86400L; days -= 1; }
    CivilFromDays(days, &year, &month, &day);

    pos = PutText(pos, end, "ts=");
    pos = PutUnsigned(pos, (unsigned long)year, 4);
    *pos++ = '-';
    pos = PutUnsigned(pos, month, 2);
    *pos++ = '-';
    pos = PutUnsigned(pos, day, 2);
    *pos++ = 'T';
    pos = PutUnsigned(pos, (unsigned long)(secs / 3600), 2);
    *pos++ = ':';
    pos = PutUnsigned(pos, (unsigned long)((secs / 60) % 60), 2);
    *pos++ = ':';
    pos = PutUnsigned(pos, (unsigned long)(secs % 60), 2);
    *pos++ = '.';
    pos = PutUnsigned(pos, (unsigned long)(now.tv_nsec / 1000), 6);
    if (g_UseUtc)
    {
        *pos++ = 'Z';
    }
    else
    {
        *pos++ = offset < 0 ? '-' : '+';
        if (offset < 0) { offset = -offset; }
        pos = PutUnsigned(pos, (unsigned long)(offset / 3600), 2);
        *pos++ = ':';
        pos = PutUnsigned(pos, (unsigned long)((offset / 60) % 60), 2);
    }
    pos = PutText(pos, end, " host=");
    pos = PutText(pos, end, g_HostName);
    pos = PutText(pos, end, " proc=");
    pos = PutText(pos, end, g_ProcName);
    pos = PutText(pos, end, " pid=");
    pos = PutUnsigned(pos, (unsigned long)getpid(), 1);
    pos = PutText(pos, end, " lvl=FATAL mod=log txn=");
    pos = PutText(pos, end, g_TxnId[0] ? g_TxnId : "-");
    pos = PutText(pos, end, " msg=crash signal=");
    pos = PutUnsigned(pos, (unsigned long)(signo < 0 ? 0 : signo), 1);
    *pos++ = '\n';
    (void)WriteAll(g_LogFd, buf, (size_t)(pos - buf));
}

/*-----------------------------------------------------------------------------
마스킹 헬퍼 — 개인정보는 필드 단위로 가린 값만 로그에 넘긴다
-----------------------------------------------------------------------------*/
#define LOG_MASK_KEEP_TAIL  4

char *LogMaskDigits(const char *src, char *out, size_t out_size)
{
    size_t digit_total = 0;
    size_t digit_seen  = 0;
    size_t keep_from   = 0;
    size_t ii;
    size_t pos         = 0;

    if (out == NULL || out_size == 0) { return out; }
    if (src == NULL) { snprintf(out, out_size, "-"); return out; }
    for (ii = 0; src[ii] != '\0'; ii++)
    {
        if (src[ii] >= '0' && src[ii] <= '9') { digit_total++; }
    }
    /* 숫자가 4자리 이하면 남기면 전부 드러나므로 모두 가린다 */
    keep_from = (digit_total > LOG_MASK_KEEP_TAIL) ? digit_total - LOG_MASK_KEEP_TAIL : digit_total;
    for (ii = 0; src[ii] != '\0' && pos < out_size - 1; ii++)
    {
        char ch = src[ii];

        if (ch >= '0' && ch <= '9')
        {
            out[pos++] = (digit_seen < keep_from) ? '*' : ch;
            digit_seen++;
        }
        else
        {
            out[pos++] = ch;
        }
    }
    out[pos] = '\0';
    return out;
}

char *LogMaskAll(const char *src, char *out, size_t out_size)
{
    if (out == NULL || out_size == 0) { return out; }
    if (src == NULL)        { snprintf(out, out_size, "-"); }
    else if (src[0] == '\0') { out[0] = '\0'; }
    else                    { snprintf(out, out_size, "%s", LOG_MASK_ALL_TEXT); }
    return out;
}
