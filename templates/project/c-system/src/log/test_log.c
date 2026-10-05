/*#############################################################################
FILE NAME   : test_log.c
DESCRIPTION : 로그 모듈 테스트 — 형식 필드, 레벨 필터의 인자 평가 생략, 폭주 억제, 마스킹, 재오픈, 비동기
#############################################################################*/
#if defined(__linux__)
#define _GNU_SOURCE
#endif

#undef NDEBUG
#include <assert.h>
#include <errno.h>
#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#include <unistd.h>

#define LOG_MODULE "test"
#include "log.h"

#define TEST_BUF_MAX    (1024 * 1024)
#define TEST_BURST      20000

static char g_TmpDir[256]     = "";
static char g_FileBuf[TEST_BUF_MAX];
static int  g_EvalCount       = 0;

/*-----------------------------------------------------------------------------
테스트 헬퍼
-----------------------------------------------------------------------------*/
static int BumpEvalCount(void)
{
    g_EvalCount++;
    return g_EvalCount;
}

static void MakePath(char *out, size_t size, const char *name)
{
    snprintf(out, size, "%s/%s", g_TmpDir, name);
}

/* 파일 전체를 g_FileBuf에 읽는다. 없으면 빈 문자열 */
static const char *ReadAll(const char *path)
{
    FILE  *fp  = fopen(path, "r");
    size_t len = 0;

    g_FileBuf[0] = '\0';
    if (fp == NULL) { return g_FileBuf; }
    len = fread(g_FileBuf, 1, sizeof(g_FileBuf) - 1, fp);
    g_FileBuf[len] = '\0';
    fclose(fp);
    return g_FileBuf;
}

static int CountLines(const char *text)
{
    int count = 0;

    for (; *text != '\0'; text++)
    {
        if (*text == '\n') { count++; }
    }
    return count;
}

static int CountOccurrences(const char *text, const char *needle)
{
    int         count = 0;
    const char *pos   = text;

    while ((pos = strstr(pos, needle)) != NULL)
    {
        count++;
        pos += strlen(needle);
    }
    return count;
}

/* "key=숫자"의 모든 값을 더한다 */
static long SumField(const char *text, const char *key)
{
    long        sum = 0;
    const char *pos = text;
    size_t      len = strlen(key);

    while ((pos = strstr(pos, key)) != NULL)
    {
        sum += strtol(pos + len, NULL, 10);
        pos += len;
    }
    return sum;
}

static LogConfig BaseConfig(const char *path)
{
    LogConfig cfg;

    memset(&cfg, 0, sizeof(cfg));
    cfg.path      = path;
    cfg.proc_name = "test_log";
    cfg.level     = LOG_LEVEL_INFO;
    return cfg;
}

static void SleepMs(long ms)
{
    struct timespec ts = { ms / 1000, (ms % 1000) * 1000000L };

    while (nanosleep(&ts, &ts) != 0 && errno == EINTR) { }
}

/*-----------------------------------------------------------------------------
테스트
-----------------------------------------------------------------------------*/
static void TestFormatFields(void)
{
    char      path[512];
    LogConfig cfg;
    const char *text;

    MakePath(path, sizeof(path), "format.log");
    cfg = BaseConfig(path);
    assert(LogInit(&cfg) == 0);
    LogSetTxnId("T20261005-0001");
    LOG_INFO("주문 접수 qty=%d", 42);
    LogClearTxnId();
    LOG_WARN("%s", "줄바꿈\n가짜 lvl=FATAL 줄");
    LogShutdown();

    text = ReadAll(path);
    assert(CountLines(text) == 2);                     /* 개행 삽입이 새 줄을 만들지 않는다 */
    assert(strncmp(text, "ts=", 3) == 0);
    assert(strstr(text, " host=") != NULL);
    assert(strstr(text, " proc=test_log ") != NULL);
    assert(strstr(text, " pid=") != NULL);
    assert(strstr(text, " tid=") != NULL);
    assert(strstr(text, " lvl=INFO ") != NULL);
    assert(strstr(text, " mod=test ") != NULL);
    assert(strstr(text, " file=test_log.c ") != NULL);
    assert(strstr(text, " fn=TestFormatFields:") != NULL);
    assert(strstr(text, " txn=T20261005-0001 msg=주문 접수 qty=42\n") != NULL);
    assert(strstr(text, " txn=- msg=줄바꿈 가짜") != NULL);
    /* 시각: YYYY-MM-DDTHH:MM:SS.uuuuuu 다음에 Z 또는 ±HH:MM */
    assert(text[13] == 'T' && text[22] == '.');
    assert(text[29] == 'Z' || text[29] == '+' || text[29] == '-');
    printf("[PASS] 형식 필드\n");
}

static void TestUtcPolicy(void)
{
    char      path[512];
    LogConfig cfg;

    MakePath(path, sizeof(path), "utc.log");
    cfg         = BaseConfig(path);
    cfg.use_utc = true;
    assert(LogInit(&cfg) == 0);
    LOG_INFO("utc");
    LogShutdown();
    assert(ReadAll(path)[29] == 'Z');
    printf("[PASS] UTC 정책\n");
}

static void TestLevelFilterSkipsEvaluation(void)
{
    char      path[512];
    LogConfig cfg;

    MakePath(path, sizeof(path), "level.log");
    cfg = BaseConfig(path);
    assert(LogInit(&cfg) == 0);
    g_EvalCount = 0;
    LOG_DEBUG("debug %d", BumpEvalCount());
    LOG_TRACE("trace %d", BumpEvalCount());
    assert(g_EvalCount == 0);                          /* 비활성 레벨은 인자를 평가하지 않는다 */
    LOG_ERROR("error %d", BumpEvalCount());
    assert(g_EvalCount == 1);
    LogSetLevel(LOG_LEVEL_TRACE);
    LOG_TRACE("trace %d", BumpEvalCount());
    assert(g_EvalCount == 2);
    LogShutdown();
    assert(CountLines(ReadAll(path)) == 2);
    printf("[PASS] 레벨 필터 — 비활성 레벨 인자 미평가\n");
}

static void LogFloodOnce(int seq)
{
    LOG_ERROR("upstream down seq=%d", seq);           /* 같은 호출 위치 */
}

static void TestFloodSuppression(void)
{
    char        path[512];
    LogConfig   cfg;
    LogStats    stats;
    const char *text;
    int         ii;

    MakePath(path, sizeof(path), "flood.log");
    cfg                  = BaseConfig(path);
    cfg.flood_max        = 3;
    cfg.flood_window_sec = 1;
    assert(LogInit(&cfg) == 0);
    for (ii = 0; ii < 10; ii++) { LogFloodOnce(ii); }
    SleepMs(1100);                                     /* 창이 바뀌면 생략 요약 후 다시 기록 */
    LogFloodOnce(100);
    for (ii = 0; ii < 5; ii++) { LogFloodOnce(200 + ii); }
    LogGetStats(&stats);
    LogShutdown();                                     /* 남은 생략분도 요약한다 */

    text = ReadAll(path);
    assert(CountOccurrences(text, "msg=upstream down") == 6);
    assert(strstr(text, "suppressed=7 ") != NULL);
    assert(strstr(text, "suppressed=3 ") != NULL);
    assert(stats.suppressed == 10);
    printf("[PASS] 폭주 억제 — 창당 3건 + 생략 요약\n");
}

static void TestMasking(void)
{
    char out[64];
    char tiny[5];

    assert(strcmp(LogMaskDigits("010-1234-5678", out, sizeof(out)), "***-****-5678") == 0);
    assert(strcmp(LogMaskDigits("1234 5678 9012 3456", out, sizeof(out)), "**** **** **** 3456") == 0);
    assert(strcmp(LogMaskDigits("123", out, sizeof(out)), "***") == 0);
    assert(strcmp(LogMaskDigits(NULL, out, sizeof(out)), "-") == 0);
    assert(strcmp(LogMaskDigits("010-1234-5678", tiny, sizeof(tiny)), "***-") == 0);
    assert(strcmp(LogMaskAll("my-password", out, sizeof(out)), "****") == 0);
    assert(strcmp(LogMaskAll("", out, sizeof(out)), "") == 0);
    assert(strcmp(LogMaskAll(NULL, out, sizeof(out)), "-") == 0);
    printf("[PASS] 마스킹 헬퍼\n");
}

static void TestReopen(void)
{
    char      path[512];
    char      rotated[512];
    LogConfig cfg;

    MakePath(path, sizeof(path), "reopen.log");
    MakePath(rotated, sizeof(rotated), "reopen.log.1");
    cfg = BaseConfig(path);
    assert(LogInit(&cfg) == 0);
    LOG_INFO("before rotate");
    assert(rename(path, rotated) == 0);                /* logrotate의 rename 단계 */
    LogRequestReopen();                                /* SIGHUP 핸들러가 하는 일 */
    assert(LogReopenIfRequested() == 0);               /* 메인 루프가 하는 일 */
    assert(LogReopenIfRequested() == 0);               /* 요청은 한 번만 처리 */
    LOG_INFO("after rotate");
    LogShutdown();

    assert(strstr(ReadAll(rotated), "msg=before rotate") != NULL);
    assert(strstr(g_FileBuf, "after rotate") == NULL);
    assert(strstr(ReadAll(path), "msg=after rotate") != NULL);
    printf("[PASS] 재오픈 — 회전 후 새 파일에 이어서 기록\n");
}

static void *TxnThreadMain(void *arg)
{
    (void)arg;
    LogSetTxnId("T-THREAD");
    LOG_INFO("worker");
    return NULL;
}

static void TestAsyncAndThreadTxn(void)
{
    char        path[512];
    LogConfig   cfg;
    pthread_t   worker;
    const char *text;
    int         ii;

    MakePath(path, sizeof(path), "async.log");
    cfg       = BaseConfig(path);
    cfg.async = true;
    assert(LogInit(&cfg) == 0);
    LogSetTxnId("T-MAIN");
    assert(pthread_create(&worker, NULL, TxnThreadMain, NULL) == 0);
    assert(pthread_join(worker, NULL) == 0);
    for (ii = 0; ii < 100; ii++) { LOG_INFO("async seq=%d", ii); }
    LogClearTxnId();
    LogShutdown();                                     /* 남은 줄을 모두 쓴 뒤 멈춘다 */

    text = ReadAll(path);
    assert(CountOccurrences(text, "txn=T-MAIN msg=async seq=") == 100);
    assert(strstr(text, "txn=T-THREAD msg=worker") != NULL);
    printf("[PASS] 비동기 기록 + 스레드별 거래 ID\n");
}

static void TestAsyncRingFullDropsInsteadOfBlocking(void)
{
    char        path[512];
    LogConfig   cfg;
    LogStats    stats;
    const char *text;
    int         ii;
    int         written;
    long        dropped;

    MakePath(path, sizeof(path), "burst.log");
    cfg            = BaseConfig(path);
    cfg.async      = true;
    cfg.ring_slots = 8;
    assert(LogInit(&cfg) == 0);
    for (ii = 0; ii < TEST_BURST; ii++) { LOG_INFO("burst %d", ii); }
    LogShutdown();
    LogGetStats(&stats);

    text    = ReadAll(path);
    written = CountOccurrences(text, "msg=burst ");
    dropped = SumField(text, "dropped=");
    assert(written + dropped == TEST_BURST);          /* 기록 + 유실 요약 = 전체 */
    assert((long)stats.dropped == dropped);
    printf("[PASS] 링버퍼 가득 참 — 블록 없이 유실 수 집계 (written=%d dropped=%ld)\n",
           written, dropped);
}

static void TestCrashNote(void)
{
    char      path[512];
    LogConfig cfg;
    const char *text;

    MakePath(path, sizeof(path), "crash.log");
    cfg = BaseConfig(path);
    assert(LogInit(&cfg) == 0);
    LogSetTxnId("T-CRASH");
    LogCrashNote(11);
    LogClearTxnId();
    LogShutdown();

    text = ReadAll(path);
    assert(strncmp(text, "ts=", 3) == 0 && text[13] == 'T' && text[22] == '.');
    assert(strstr(text, " lvl=FATAL ") != NULL);
    assert(strstr(text, " txn=T-CRASH msg=crash signal=11\n") != NULL);
    printf("[PASS] 크래시 줄 — async-signal-safe 형식\n");
}

static void TestInitErrors(void)
{
    LogConfig cfg = BaseConfig(NULL);

    assert(LogInit(NULL) == -EINVAL);
    cfg.flood_max = 3;
    assert(LogInit(&cfg) == -EINVAL);                  /* 창 길이 없는 억제 */
    cfg.flood_max = 0;
    assert(LogInit(&cfg) == 0);
    assert(LogInit(&cfg) == -EALREADY);
    assert(LogReopen() == 0);                          /* 표준 에러 출력은 재오픈 대상 아님 */
    LogShutdown();
    printf("[PASS] 초기화 오류 처리\n");
}

static void RemoveTmpDir(void)
{
    static const char *const names[] = {
        "format.log", "utc.log", "level.log", "flood.log", "reopen.log", "reopen.log.1",
        "async.log", "burst.log", "crash.log"
    };
    char   path[512];
    size_t ii;

    for (ii = 0; ii < sizeof(names) / sizeof(names[0]); ii++)
    {
        MakePath(path, sizeof(path), names[ii]);
        unlink(path);
    }
    rmdir(g_TmpDir);
}

int main(void)
{
    snprintf(g_TmpDir, sizeof(g_TmpDir), "test_tmp.XXXXXX");
    assert(mkdtemp(g_TmpDir) != NULL);

    TestFormatFields();
    TestUtcPolicy();
    TestLevelFilterSkipsEvaluation();
    TestFloodSuppression();
    TestMasking();
    TestReopen();
    TestAsyncAndThreadTxn();
    TestAsyncRingFullDropsInsteadOfBlocking();
    TestCrashNote();
    TestInitErrors();

    RemoveTmpDir();
    printf("[PASS] test_log 전체 통과\n");
    return 0;
}
