/*#############################################################################
FILE NAME   : shm_recover.c
DESCRIPTION : 공유메모리 헤더 검증·손상 판정·원천 재적재 도구(기본 dry-run)
#############################################################################*/
#define _POSIX_C_SOURCE 200809L
#define LOG_MODULE "recover"

/* 1. 표준 라이브러리 */
#include <errno.h>
#include <inttypes.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* 2. POSIX / 시스템 헤더 */
#include <unistd.h>

/* 4. 프로젝트 내부 헤더 */
#include "log.h"
#include "rec_loader.h"
#include "shm_segment.h"
#include "shm_tool.h"
#include "sorted_table.h"

#define FETCH_BATCH_ROWS    1024u
#define CONFIRM_LINE_MAX    128u

typedef enum RecoverMode
{
    MODE_DRY_RUN,       /* 판정 + 원천 점검 + 계획 출력. 세그먼트는 읽기 전용으로만 연다 */
    MODE_VERIFY_ONLY,   /* 판정만 */
    MODE_APPLY,         /* 실제 재적재 */
} RecoverMode;

typedef struct RecoverOpts
{
    const char *name;
    const char *source;         /* "file:<경로>" 또는 "db:<별칭>" */
    const char *log_path;       /* 운영 로그 파일. NULL 이면 표준 에러 */
    uint32_t    cap;            /* --cap: 헤더 rec_cap 을 믿을 수 없을 때 */
    RecoverMode mode;
    bool        force_reload;   /* 정상이어도 재적재, RECOVERING 잔존 상태 이어받기 */
    bool        assume_yes;     /* 확인 프롬프트 생략 */
} RecoverOpts;

typedef struct Diagnosis
{
    int      hdr_rc;            /* ShmHdrCheck 결과(CORRUPT 허용 플래그로) */
    uint32_t state;
    int      checksum_rc;       /* 0 일치, -EBADMSG 불일치, 1 검사 생략 */
    int      sorted_rc;         /* 0 정상, -EILSEQ 위반, 1 검사 생략 */
    bool     is_corrupt;
    bool     need_reset_hdr;    /* 헤더 자체를 다시 써야 한다 */
} Diagnosis;

typedef struct Staging
{
    ItemRec *recs;
    uint32_t cnt;
    uint64_t checksum;
} Staging;

static void PrintUsage(void)
{
    fprintf(stderr,
            "사용법: shm_recover --name /<이름> [--source file:<경로>|db:<별칭>]\n"
            "                    [--dry-run(기본) | --verify-only | --apply [--yes]]\n"
            "                    [--force-reload] [--cap <레코드 수>] [--log <로그 파일>]\n"
            "종료 코드: 0 정상·성공, 1 오류, 2 손상 판정, 3 안전 조건으로 거부\n");
}

static int ParseOpts(int argc, char **argv, RecoverOpts *opts)
{
    int ii = 0;

    memset(opts, 0, sizeof(*opts));
    opts->mode = MODE_DRY_RUN;
    for (ii = 1; ii < argc; ii++)
    {
        const char *arg     = argv[ii];
        const char *nextarg = (ii + 1 < argc) ? argv[ii + 1] : NULL;

        if (strcmp(arg, "--dry-run") == 0)          { opts->mode = MODE_DRY_RUN; }
        else if (strcmp(arg, "--verify-only") == 0) { opts->mode = MODE_VERIFY_ONLY; }
        else if (strcmp(arg, "--apply") == 0)       { opts->mode = MODE_APPLY; }
        else if (strcmp(arg, "--force-reload") == 0) { opts->force_reload = true; }
        else if (strcmp(arg, "--yes") == 0)         { opts->assume_yes = true; }
        else if (nextarg == NULL)                   { return -EINVAL; }
        else if (strcmp(arg, "--name") == 0)        { opts->name = nextarg; ii++; }
        else if (strcmp(arg, "--source") == 0)      { opts->source = nextarg; ii++; }
        else if (strcmp(arg, "--log") == 0)         { opts->log_path = nextarg; ii++; }
        else if (strcmp(arg, "--cap") == 0)
        {
            char         *end = NULL;
            unsigned long val = strtoul(nextarg, &end, 10);

            if (*end != '\0' || val == 0 || val > UINT32_MAX)
            {
                return -EINVAL;
            }
            opts->cap = (uint32_t)val;
            ii++;
        }
        else
        {
            return -EINVAL;
        }
    }
    return ShmToolNameValid(opts->name) ? 0 : -EINVAL;
}

static const char *HdrReason(int hdr_rc)
{
    switch (hdr_rc)
    {
    case 0:        return "ok";
    case -EAGAIN:  return "매직 0 — 초기화 중이거나 초기화 중 중단";
    case -EBADMSG: return "매직 불일치";
    case -EPROTO:  return "레이아웃 버전·레코드 크기 불일치";
    case -EINVAL:  return "용량·건수·매핑 크기 불일치";
    case -EIO:     return "상태 플래그 값이 범위 밖";
    default:       return "알 수 없음";
    }
}

/*=============================================================================
FUNCTION    : Diagnose
DESCRIPTION : 헤더(매직·버전·레코드 크기·용량·상태) → 체크섬 → 정렬 불변식 순으로
              판정한다. 헤더가 틀리면 레코드 영역은 믿을 수 없으므로 뒤 검사는 생략한다
=============================================================================*/
static void Diagnose(ShmSeg *seg, const ShmLayout *layout, Diagnosis *diag)
{
    ShmHdr   *hdr = ShmSegHdr(seg);
    ItemTable tbl;
    uint32_t  cnt = 0;

    memset(diag, 0, sizeof(*diag));
    diag->hdr_rc      = ShmHdrCheck(hdr, layout, ShmSegMapSize(seg), SHM_ATTACH_ALLOW_CORRUPT);
    diag->state       = atomic_load(&hdr->state);
    diag->checksum_rc = 1;
    diag->sorted_rc   = 1;
    if (diag->hdr_rc == 0)
    {
        /* 락 없이 읽는다 — 작성자가 살아 있으면 일시 불일치가 보일 수 있다(런북: 재확인) */
        diag->checksum_rc = ShmSegVerifyChecksum(seg);
        cnt               = hdr->rec_cnt;
        ItemTableBind(&tbl, ShmSegData(seg), &cnt, hdr->rec_cap);
        diag->sorted_rc = ItemTableCheckSorted(&tbl);
    }
    diag->need_reset_hdr = (diag->hdr_rc != 0);
    diag->is_corrupt     = diag->need_reset_hdr || diag->state != SHM_STATE_READY ||
                           diag->checksum_rc != 0 || diag->sorted_rc != 0;
}

static void PrintDiagnosis(const char *name, const ShmHdr *hdr, const Diagnosis *diag)
{
    ShmToolPrintHdr(stdout, name, hdr);
    printf("check.header=%s\n", HdrReason(diag->hdr_rc));
    printf("check.state=%s\n", ShmToolStateName(diag->state));
    printf("check.checksum=%s\n", diag->checksum_rc == 1 ? "skip" :
                                  (diag->checksum_rc == 0 ? "ok" : "mismatch"));
    printf("check.sorted=%s\n", diag->sorted_rc == 1 ? "skip" :
                                (diag->sorted_rc == 0 ? "ok" : "violation"));
    printf("verdict=%s\n", diag->is_corrupt ? "CORRUPT" : "OK");
}

/*=============================================================================
FUNCTION    : LoadStaging
DESCRIPTION : 원천 전량을 프로세스 지역 임시 영역에 읽고 정렬·중복 검사·체크섬까지 끝낸다.
              공유메모리는 건드리지 않는다
PARAMETERS  : const RecLoaderOps *ops - 원천 구현
              const char *src         - 원천 문자열
              uint32_t cap            - 세그먼트 용량
              Staging *out            - 결과(recs 는 호출자가 free)
RETURNED    : 0 성공, -ENOSPC 용량 초과, -EEXIST 중복 키, 그 밖의 음수 errno
=============================================================================*/
static int LoadStaging(const RecLoaderOps *ops, const char *src, uint32_t cap, Staging *out)
{
    ItemRec  *raw   = calloc(cap, sizeof(ItemRec));
    ItemRec  *recs  = calloc(cap, sizeof(ItemRec));
    void     *impl  = NULL;
    uint32_t  total = 0;
    int       ret   = 0;
    ItemTable tbl;

    if (raw == NULL || recs == NULL)
    {
        ret = -ENOMEM;
        goto cleanup;
    }
    ret = ops->Open(src, &impl);
    while (ret == 0)
    {
        ItemRec  probe;
        uint32_t room = cap - total;
        int      got  = 0;

        if (room == 0)
        {
            /* 용량이 찼다 — 원천에 더 남았으면 용량 초과다 */
            got = ops->FetchBatch(impl, &probe, 1);
            ret = (got > 0) ? -ENOSPC : (got < 0 ? got : 0);
            break;
        }
        got = ops->FetchBatch(impl, raw + total, room < FETCH_BATCH_ROWS ? room : FETCH_BATCH_ROWS);
        if (got <= 0)
        {
            ret = got;
            break;
        }
        total += (uint32_t)got;
        LOG_DEBUG("원천 묶음 읽음 got=%d total=%u", got, total);
    }
    if (ret == 0)
    {
        ItemTableBind(&tbl, recs, &out->cnt, cap);
        ret = ItemTableBulkLoad(&tbl, raw, total);      /* qsort + 중복 검사 */
        ret = (ret < 0) ? ret : ItemTableCheckSorted(&tbl);
    }
    if (ret == 0)
    {
        out->recs     = recs;
        out->checksum = ShmChecksum(recs, (size_t)out->cnt * sizeof(ItemRec));
        recs          = NULL;
    }

cleanup:
    ops->Close(impl);
    free(raw);
    free(recs);
    return ret;
}

/* 재적재로 레코드 영역을 통째로 바꾸므로 죽은 소유자의 부분 갱신은 버려도 된다 */
static int RepairByReload(ShmSeg *seg, void *ctx)
{
    (void)seg;
    (void)ctx;
    return 0;
}

/*=============================================================================
FUNCTION    : EnterRecovering
DESCRIPTION : 현재 상태에서 RECOVERING 으로 전이한다. 헤더가 깨졌으면 헤더를 다시 쓴다.
              전이표: READY→RECOVERING, CORRUPT→RECOVERING, INIT→CORRUPT→RECOVERING
RETURNED    : 0 성공, -EBUSY 다른 복구 진행 중(--force-reload 없음), 그 밖의 음수 errno
=============================================================================*/
static int EnterRecovering(ShmSeg *seg, const ShmLayout *layout, const Diagnosis *diag,
                           bool force_reload)
{
    uint32_t state = atomic_load(&ShmSegHdr(seg)->state);

    if (diag->need_reset_hdr)
    {
        LOG_WARN("헤더 재작성 reason=%s", HdrReason(diag->hdr_rc));
        return ShmSegResetHdr(seg, layout);
    }
    switch (state)
    {
    case SHM_STATE_READY:
    case SHM_STATE_CORRUPT:
        return ShmSegSetState(seg, (ShmState)state, SHM_STATE_RECOVERING);
    case SHM_STATE_INIT:
        if (ShmSegSetState(seg, SHM_STATE_INIT, SHM_STATE_CORRUPT) != 0)
        {
            return -EAGAIN;
        }
        return ShmSegSetState(seg, SHM_STATE_CORRUPT, SHM_STATE_RECOVERING);
    case SHM_STATE_RECOVERING:
        return force_reload ? 0 : -EBUSY;
    default:
        return -EIO;
    }
}

/*=============================================================================
FUNCTION    : CopyAndVerify
DESCRIPTION : 락 안에서 임시 영역을 세그먼트로 복사하고 건수·체크섬·정렬을 검증한다.
              락 안에서는 로그를 쓰지 않는다
RETURNED    : 0 성공, -EBADMSG 검증 실패, 그 밖의 음수 errno
=============================================================================*/
static int CopyAndVerify(ShmSeg *seg, const Staging *stg)
{
    ShmHdr   *hdr = ShmSegHdr(seg);
    ItemTable tbl;
    uint32_t  cnt = 0;
    int       ret = ShmSegLock(seg, RepairByReload, NULL);

    if (ret < 0)
    {
        return ret;
    }
    memcpy(ShmSegData(seg), stg->recs, (size_t)stg->cnt * sizeof(ItemRec));
    hdr->rec_cnt = stg->cnt;
    hdr->load_seq++;
    ShmSegUpdateChecksum(seg);

    cnt = hdr->rec_cnt;
    ItemTableBind(&tbl, ShmSegData(seg), &cnt, hdr->rec_cap);
    if (hdr->rec_cnt != stg->cnt || hdr->checksum != stg->checksum ||
        ShmSegVerifyChecksum(seg) != 0 || ItemTableCheckSorted(&tbl) != 0)
    {
        ret = -EBADMSG;
    }
    else
    {
        ret = 0;
    }
    ShmSegUnlock(seg);
    return ret;
}

/*=============================================================================
FUNCTION    : ConfirmApply
DESCRIPTION : --yes 가 없으면 터미널에서 세그먼트 이름을 다시 입력받는다.
              터미널이 아니면 거부한다(스크립트에서 실수로 실행되는 것을 막는다)
=============================================================================*/
static bool ConfirmApply(const RecoverOpts *opts)
{
    char line[CONFIRM_LINE_MAX];

    if (opts->assume_yes)
    {
        return true;
    }
    if (!isatty(STDIN_FILENO))
    {
        fprintf(stderr, "[shm_recover] 터미널이 아니다 — 확인 후 --yes 로 다시 실행한다\n");
        return false;
    }
    fprintf(stderr, "세그먼트 %s 를 재적재한다. 계속하려면 이름을 그대로 입력: ", opts->name);
    if (fgets(line, sizeof(line), stdin) == NULL)
    {
        return false;
    }
    line[strcspn(line, "\r\n")] = '\0';
    return strcmp(line, opts->name) == 0;
}

static int CheckApplySafety(const RecoverOpts *opts, const Diagnosis *diag)
{
    int attach_cnt = ShmToolAttachCount(opts->name);

    if (attach_cnt > 0 && diag->need_reset_hdr)
    {
        LOG_ERROR("헤더 재작성 거부 attach_cnt=%d — 소유·조회 프로세스를 먼저 멈춘다", attach_cnt);
        return TOOL_EXIT_REFUSED;
    }
    if (attach_cnt < 0)
    {
        LOG_WARN("attach 프로세스 수를 셀 수 없다(이 플랫폼) — 소유 프로세스 중지를 직접 확인한다");
    }
    if (!ConfirmApply(opts))
    {
        LOG_WARN("사용자 확인 없음 — 재적재 취소");
        return TOOL_EXIT_REFUSED;
    }
    return TOOL_EXIT_OK;
}

static int RunApply(ShmSeg *seg, const ShmLayout *layout, const RecoverOpts *opts,
                    const Diagnosis *diag, const Staging *stg)
{
    int ret = CheckApplySafety(opts, diag);

    if (ret != TOOL_EXIT_OK)
    {
        return ret;
    }
    ret = EnterRecovering(seg, layout, diag, opts->force_reload);
    if (ret != 0)
    {
        LOG_ERROR("RECOVERING 전환 실패 rc=%d — 다른 복구가 진행 중이면 끝나기를 기다린다", ret);
        return (ret == -EBUSY) ? TOOL_EXIT_REFUSED : TOOL_EXIT_ERROR;
    }
    LOG_INFO("상태 전환 to=RECOVERING segment=%s", opts->name);
    ret = CopyAndVerify(seg, stg);
    if (ret != 0)
    {
        ShmSegSetState(seg, SHM_STATE_RECOVERING, SHM_STATE_CORRUPT);
        LOG_ERROR("복사·검증 실패 rc=%d — 상태를 CORRUPT 로 둔다", ret);
        return TOOL_EXIT_ERROR;
    }
    LOG_INFO("세그먼트 검증 통과 rec_cnt=%u checksum=0x%016" PRIx64, stg->cnt, stg->checksum);
    ret = ShmSegSetState(seg, SHM_STATE_RECOVERING, SHM_STATE_READY);
    if (ret != 0)
    {
        LOG_ERROR("READY 전환 실패 rc=%d", ret);
        return TOOL_EXIT_ERROR;
    }
    LOG_INFO("상태 전환 to=READY segment=%s load_seq=%" PRIu64, opts->name,
             ShmSegHdr(seg)->load_seq);
    printf("result=READY rec_cnt=%u checksum=0x%016" PRIx64 "\n", stg->cnt, stg->checksum);
    return TOOL_EXIT_OK;
}

static void PrintPlan(const Diagnosis *diag, const RecoverOpts *opts, const Staging *stg)
{
    printf("plan.1=%s\n", diag->need_reset_hdr ? "헤더 재작성(ShmSegResetHdr) → RECOVERING"
                                               : "상태 전이 → RECOVERING");
    printf("plan.2=원천 %s 에서 임시 영역 적재(%u건, 정렬·중복 검사 통과, checksum=0x%016" PRIx64 ")\n",
           opts->source, stg->cnt, stg->checksum);
    printf("plan.3=락 안에서 복사 → 건수·체크섬·정렬 검증\n");
    printf("plan.4=RECOVERING → READY (실패 시 CORRUPT)\n");
    printf("result=dry-run 변경 없음 — 실행은 --apply\n");
}

/*=============================================================================
FUNCTION    : Run
DESCRIPTION : 헤더 엿보기 → attach(검증 생략) → 판정 → 모드별 처리
RETURNED    : 도구 종료 코드(TOOL_EXIT_*)
=============================================================================*/
static int Run(const RecoverOpts *opts)
{
    const RecLoaderOps *ops    = NULL;
    const char         *src    = NULL;
    ShmSeg             *seg    = NULL;
    Staging             stg    = { NULL, 0, 0 };
    ShmHdr              peek;
    ShmLayout           layout;
    Diagnosis           diag;
    int                 ret    = 0;
    uint32_t            flags  = SHM_ATTACH_NO_CHECK |
                                 (opts->mode == MODE_APPLY ? 0u : SHM_ATTACH_RDONLY);

    ret = ShmSegPeekHdr(opts->name, &peek);
    if (ret == 0)
    {
        ret = ShmToolLayout(&peek, opts->cap, &layout);
    }
    if (ret == 0)
    {
        ret = ShmSegAttach(opts->name, &layout, flags, &seg);
    }
    if (ret != 0)
    {
        LOG_ERROR("attach 실패 segment=%s rc=%d — 헤더 rec_cap 이 깨졌으면 --cap 으로 지정한다",
                  opts->name, ret);
        return TOOL_EXIT_ERROR;
    }
    Diagnose(seg, &layout, &diag);
    PrintDiagnosis(opts->name, ShmSegHdr(seg), &diag);
    LOG_INFO("판정 segment=%s verdict=%s header=%d checksum=%d sorted=%d", opts->name,
             diag.is_corrupt ? "CORRUPT" : "OK", diag.hdr_rc, diag.checksum_rc, diag.sorted_rc);

    if (opts->mode == MODE_VERIFY_ONLY || (!diag.is_corrupt && !opts->force_reload))
    {
        ret = diag.is_corrupt ? TOOL_EXIT_CORRUPT : TOOL_EXIT_OK;
        goto cleanup;
    }
    ops = RecLoaderSelect(opts->source, &src);
    if (ops == NULL)
    {
        LOG_ERROR("--source 가 없거나 형식이 틀렸다(file:<경로> 또는 db:<별칭>)");
        ret = TOOL_EXIT_ERROR;
        goto cleanup;
    }
    ret = LoadStaging(ops, src, layout.rec_cap, &stg);
    if (ret != 0)
    {
        LOG_ERROR("임시 영역 적재 실패 source=%s rc=%d — 세그먼트는 바꾸지 않았다", ops->kind, ret);
        ret = TOOL_EXIT_ERROR;
        goto cleanup;
    }
    LOG_INFO("임시 영역 적재·검증 통과 source=%s rec_cnt=%u", ops->kind, stg.cnt);
    if (opts->mode == MODE_DRY_RUN)
    {
        PrintPlan(&diag, opts, &stg);
        ret = diag.is_corrupt ? TOOL_EXIT_CORRUPT : TOOL_EXIT_OK;
        goto cleanup;
    }
    ret = RunApply(seg, &layout, opts, &diag, &stg);

cleanup:
    free(stg.recs);
    ShmSegDetach(seg);
    return ret;
}

int main(int argc, char **argv)
{
    RecoverOpts opts;
    LogConfig   log_cfg;
    int         ret = 0;

    if (ParseOpts(argc, argv, &opts) != 0)
    {
        PrintUsage();
        return TOOL_EXIT_ERROR;
    }
    memset(&log_cfg, 0, sizeof(log_cfg));
    log_cfg.path      = opts.log_path;
    log_cfg.proc_name = "shm_recover";
    log_cfg.level     = LOG_LEVEL_INFO;
    if (LogInit(&log_cfg) != 0)
    {
        fprintf(stderr, "[shm_recover] 로그 초기화 실패\n");
        return TOOL_EXIT_ERROR;
    }
    LOG_INFO("시작 segment=%s mode=%s force_reload=%d", opts.name,
             opts.mode == MODE_APPLY ? "apply" :
             (opts.mode == MODE_VERIFY_ONLY ? "verify-only" : "dry-run"), opts.force_reload);
    ret = Run(&opts);
    LOG_INFO("종료 segment=%s exit=%d", opts.name, ret);
    LogShutdown();
    return ret;
}
