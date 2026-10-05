/*#############################################################################
FILE NAME   : log.h
DESCRIPTION : 운영 로그 모듈 공개 인터페이스 — 레벨 매크로·초기화·재오픈·거래 ID·마스킹
#############################################################################*/
/*
 * 사용 규약 (정본: skills/operational-logging/SKILL.md)
 *  - 한 줄 한 이벤트, key=value 형식으로 기록한다.
 *    ts=… host=… proc=… pid=… tid=… lvl=… mod=… file=… fn=함수:줄 txn=… msg=…
 *  - 모듈 이름은 .c 파일에서 이 헤더를 포함하기 전에 정한다.
 *        #define LOG_MODULE "ipc"
 *        #include "log.h"
 *  - 레벨 매크로는 비활성 레벨이면 인자를 평가하지 않는다. 인자에 부작용을 두지 않는다.
 *  - 포맷 문자열은 항상 리터럴이다. 사용자 입력은 LOG_INFO("%s", input)처럼 인자로 넘긴다.
 *  - 개인정보는 LogMaskDigits·LogMaskAll로 가린 값만 넘긴다. 비밀값은 아예 넘기지 않는다.
 *  - 함수형 매크로 금지(D14)의 예외는 호출 위치(__FILE__·__LINE__)를 담는 아래 로그 매크로뿐이다.
 */
#ifndef LOG_H
#define LOG_H

#include <stdatomic.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#ifndef LOG_MODULE
#define LOG_MODULE "-"
#endif

#define LOG_LINE_MAX        1024    /* 한 줄 최대 길이 — 한 번의 write()로 끝나는 크기 */
#define LOG_TXN_ID_MAX      64      /* 거래/요청 ID 최대 길이(NUL 포함) */
#define LOG_PATH_MAX        512     /* 로그 파일 경로 최대 길이 */
#define LOG_MASK_ALL_TEXT   "****"  /* LogMaskAll 출력 — 길이를 드러내지 않는 고정 문자열 */

typedef enum
{
    LOG_LEVEL_TRACE = 0,    /* 건별 상세 — 운영 기본 꺼짐 */
    LOG_LEVEL_DEBUG = 1,    /* 개발·장애 분석용 */
    LOG_LEVEL_INFO  = 2,    /* 상태 전환·기동/종료·주기 통계 */
    LOG_LEVEL_WARN  = 3,    /* 자동 복구됨·임계 근접 */
    LOG_LEVEL_ERROR = 4,    /* 요청·작업 실패 — 조치 필요 */
    LOG_LEVEL_FATAL = 5,    /* 프로세스 종료 직전 */
    LOG_LEVEL_OFF   = 6
} LogLevel;

typedef struct
{
    const char *path;               /* 로그 파일 경로. NULL이면 표준 에러 */
    const char *proc_name;          /* 프로세스 이름(proc= 필드). NULL이면 "-" */
    LogLevel    level;              /* 최소 기록 레벨 */
    bool        use_utc;            /* true: UTC(Z), false: 로컬 시각 + 오프셋 */
    bool        async;              /* true: 링버퍼 + 로거 스레드 */
    size_t      ring_slots;         /* 비동기 링버퍼 칸 수. 0이면 기본값 */
    unsigned    flood_max;          /* 같은 호출 위치의 창당 최대 기록 수. 0이면 억제 끔 */
    unsigned    flood_window_sec;   /* 폭주 억제 창 길이(초) */
} LogConfig;

typedef struct
{
    uint64_t    dropped;            /* 링버퍼가 가득 차 버린 줄 수(누적) */
    uint64_t    suppressed;         /* 폭주 억제로 생략한 줄 수(누적) */
    uint64_t    write_errors;       /* write() 실패 횟수(누적) — 디스크 풀 등 */
} LogStats;

/* 레벨 검사용 전역 — 매크로가 함수 호출 없이 읽는다. 직접 쓰지 말고 LogSetLevel을 쓴다 */
extern _Atomic int g_LogMinLevel;

/*-----------------------------------------------------------------------------
레벨 매크로 — 비활성 레벨이면 LogWrite 호출과 인자 평가를 모두 건너뛴다
-----------------------------------------------------------------------------*/
#define LOG_AT(level, ...)                                                    \
    do                                                                        \
    {                                                                         \
        if ((int)(level) >= atomic_load_explicit(&g_LogMinLevel,              \
                                                 memory_order_relaxed))       \
        {                                                                     \
            LogWrite((level), LOG_MODULE, __FILE__, __LINE__, __func__,       \
                     __VA_ARGS__);                                            \
        }                                                                     \
    } while (0)

#define LOG_TRACE(...)  LOG_AT(LOG_LEVEL_TRACE, __VA_ARGS__)
#define LOG_DEBUG(...)  LOG_AT(LOG_LEVEL_DEBUG, __VA_ARGS__)
#define LOG_INFO(...)   LOG_AT(LOG_LEVEL_INFO, __VA_ARGS__)
#define LOG_WARN(...)   LOG_AT(LOG_LEVEL_WARN, __VA_ARGS__)
#define LOG_ERROR(...)  LOG_AT(LOG_LEVEL_ERROR, __VA_ARGS__)
#define LOG_FATAL(...)  LOG_AT(LOG_LEVEL_FATAL, __VA_ARGS__)

/*=============================================================================
FUNCTION    : LogInit
DESCRIPTION : 로그 모듈을 초기화한다. 비동기 모드면 링버퍼를 미리 할당하고 로거 스레드를 띄운다.
              로거 스레드는 fork를 넘지 않는다. 워커를 fork하는 서버는 fork 뒤 각 워커에서
              LogInit을 부르고, 부모는 fork를 마칠 때까지 동기 모드를 쓴다.
PARAMETERS  : const LogConfig *cfg - 설정
RETURNED    : 0 성공, -EINVAL 잘못된 설정, -EALREADY 이미 초기화됨, 그 밖의 -errno
=============================================================================*/
int LogInit(const LogConfig *cfg);

/*=============================================================================
FUNCTION    : LogShutdown
DESCRIPTION : 남은 줄과 폭주 억제·유실 요약을 기록하고 로거 스레드를 멈춘 뒤 파일을 닫는다.
=============================================================================*/
void LogShutdown(void);

/*=============================================================================
FUNCTION    : LogReopen
DESCRIPTION : 같은 경로로 로그 파일을 다시 연다(logrotate 후). 시그널 핸들러에서 부르지 않는다.
              SIGHUP 핸들러는 플래그만 세우고, 메인 루프가 이 함수를 부른다.
RETURNED    : 0 성공(표준 에러 출력이면 아무 일도 하지 않음), 실패 시 -errno(기존 파일 유지)
=============================================================================*/
int LogReopen(void);

/*=============================================================================
FUNCTION    : LogRequestReopen / LogReopenIfRequested
DESCRIPTION : LogRequestReopen은 async-signal-safe다. SIGHUP 핸들러에서 불러 플래그만 세운다.
              LogReopenIfRequested는 메인 루프에서 불러 플래그가 있으면 LogReopen을 한다.
RETURNED    : LogReopenIfRequested — 요청 없음 0, 그 밖에는 LogReopen 반환값
=============================================================================*/
void LogRequestReopen(void);
int  LogReopenIfRequested(void);

void     LogSetLevel(LogLevel level);
LogLevel LogGetLevel(void);

/*=============================================================================
FUNCTION    : LogSetTxnId / LogClearTxnId / LogGetTxnId
DESCRIPTION : 현재 스레드의 거래/요청 ID를 정한다(스레드 지역). 요청 처리를 시작할 때 정하고
              끝나면 지운다. 정하지 않으면 txn=- 로 기록한다. 공백·제어 문자는 '_'로 바꾼다.
PARAMETERS  : const char *txn_id - 거래 ID (최대 LOG_TXN_ID_MAX-1자, 넘으면 자름)
=============================================================================*/
void        LogSetTxnId(const char *txn_id);
void        LogClearTxnId(void);
const char *LogGetTxnId(void);

/*=============================================================================
FUNCTION    : LogFlush
DESCRIPTION : 비동기 모드에서 링버퍼가 비고 기록이 끝날 때까지 기다린다. 동기 모드는 즉시 반환한다.
=============================================================================*/
void LogFlush(void);

/*=============================================================================
FUNCTION    : LogCrashNote
DESCRIPTION : 크래시 시그널 핸들러 전용. async-signal-safe 함수(clock_gettime·write)만 써서
              FATAL 한 줄을 남긴다. 링버퍼에 남은 줄은 기록하지 않는다(락이 필요하기 때문).
PARAMETERS  : int signo - 받은 시그널 번호
=============================================================================*/
void LogCrashNote(int signo);

/*=============================================================================
FUNCTION    : LogGetStats
DESCRIPTION : 유실·억제·쓰기 실패 누적 수를 돌려준다(주기 통계 로그용).
PARAMETERS  : LogStats *out - 결과
=============================================================================*/
void LogGetStats(LogStats *out);

/*=============================================================================
FUNCTION    : LogWrite
DESCRIPTION : 레벨 매크로가 부르는 실제 기록 함수. 직접 부르지 않는다.
=============================================================================*/
void LogWrite(LogLevel level, const char *module, const char *file, int line,
              const char *func, const char *fmt, ...)
    __attribute__((format(printf, 6, 7)));

/*=============================================================================
FUNCTION    : LogMaskDigits
DESCRIPTION : 숫자 중 마지막 4자리만 남기고 나머지 숫자를 '*'로 가린다. 구분자(-, 공백)는 유지한다.
              숫자가 4자리 이하면 모두 가린다. 예) 010-1234-5678 → ***-****-5678
PARAMETERS  : const char *src      - 원문 (NULL이면 "-")
              char       *out      - 결과 버퍼
              size_t      out_size - 결과 버퍼 크기 (넘치면 잘리고 항상 NUL 종료)
RETURNED    : out
=============================================================================*/
char *LogMaskDigits(const char *src, char *out, size_t out_size);

/*=============================================================================
FUNCTION    : LogMaskAll
DESCRIPTION : 값 전체를 고정 문자열 "****"로 바꾼다. 길이도 드러내지 않는다. 빈 문자열은 빈 문자열.
PARAMETERS  : const char *src      - 원문 (NULL이면 "-")
              char       *out      - 결과 버퍼
              size_t      out_size - 결과 버퍼 크기
RETURNED    : out
=============================================================================*/
char *LogMaskAll(const char *src, char *out, size_t out_size);

#endif /* LOG_H */
