/*#############################################################################
FILE NAME   : shm_view.c
DESCRIPTION : 공유메모리 읽기 전용 조회 도구 — 헤더·목록·키·범위 조회, 필드 단위 출력, 기본 마스킹
#############################################################################*/
#define _POSIX_C_SOURCE 200809L

/* 1. 표준 라이브러리 */
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* 2. POSIX / 시스템 헤더 */
#include <fcntl.h>
#include <unistd.h>

/* 4. 프로젝트 내부 헤더 */
#include "item_field.h"
#include "shm_segment.h"
#include "shm_tool.h"
#include "sorted_table.h"

#define VIEW_DEFAULT_LIMIT      100u
#define VIEW_DEFAULT_AUDIT_LOG  "./shm_view_audit.log"
#define VIEW_REASON_MIN_LEN     4u
#define VIEW_REASON_MAX_LEN     200u
#define VIEW_AUDIT_LINE_MAX     512u
#define VIEW_QUERY_TEXT_MAX     64u

typedef enum ViewQuery
{
    QUERY_LIST,
    QUERY_HEADER,
    QUERY_KEY,
    QUERY_RANGE,
} ViewQuery;

typedef struct ViewOpts
{
    const char *name;
    const char *unmask_reason;      /* NULL 이면 마스킹 유지 */
    const char *audit_path;
    ViewQuery   query;
    uint32_t    key_lo;
    uint32_t    key_hi;
    uint32_t    limit;
    uint32_t    cap;
    bool        is_csv;
} ViewOpts;

static void PrintUsage(void)
{
    fprintf(stderr,
            "사용법: shm_view --name /<이름> [--header | --list [--limit N] | --key <ID> |\n"
            "                 --range <LO> <HI>] [--format table|csv] [--cap <레코드 수>]\n"
            "                 [--unmask <사유> [--audit-log <경로>]]\n"
            "  세그먼트는 읽기 전용(O_RDONLY·PROT_READ)으로만 연다.\n"
            "  개인정보 필드는 기본 마스킹. --unmask 는 사유를 감사 로그(기본 %s)에 남긴 뒤 원문을 보인다.\n",
            VIEW_DEFAULT_AUDIT_LOG);
}

static int ParseU32(const char *text, uint32_t *out)
{
    char         *end = NULL;
    unsigned long val = 0;

    if (text == NULL || text[0] == '\0' || text[0] == '-')
    {
        return -EINVAL;
    }
    errno = 0;
    val   = strtoul(text, &end, 10);
    if (errno != 0 || *end != '\0' || val > UINT32_MAX)
    {
        return -EINVAL;
    }
    *out = (uint32_t)val;
    return 0;
}

static int ParseValueOpt(const char *arg, char **argv, int argc, int *idx, ViewOpts *opts)
{
    const char *val = (*idx + 1 < argc) ? argv[*idx + 1] : NULL;
    int         bad = 0;

    if (val == NULL)
    {
        return -EINVAL;
    }
    (*idx)++;
    if (strcmp(arg, "--name") == 0)           { opts->name = val; }
    else if (strcmp(arg, "--unmask") == 0)    { opts->unmask_reason = val; }
    else if (strcmp(arg, "--audit-log") == 0) { opts->audit_path = val; }
    else if (strcmp(arg, "--limit") == 0)     { bad = ParseU32(val, &opts->limit); }
    else if (strcmp(arg, "--cap") == 0)       { bad = ParseU32(val, &opts->cap); }
    else if (strcmp(arg, "--format") == 0)
    {
        opts->is_csv = (strcmp(val, "csv") == 0);
        bad          = (opts->is_csv || strcmp(val, "table") == 0) ? 0 : -EINVAL;
    }
    else if (strcmp(arg, "--key") == 0)
    {
        opts->query = QUERY_KEY;
        bad         = ParseU32(val, &opts->key_lo);
    }
    else if (strcmp(arg, "--range") == 0)
    {
        opts->query = QUERY_RANGE;
        bad         = ParseU32(val, &opts->key_lo);
        if (bad == 0 && *idx + 1 < argc)
        {
            (*idx)++;
            bad = ParseU32(argv[*idx], &opts->key_hi);
        }
        else
        {
            bad = -EINVAL;
        }
    }
    else
    {
        bad = -EINVAL;
    }
    return bad;
}

static int ParseOpts(int argc, char **argv, ViewOpts *opts)
{
    int ii = 0;

    memset(opts, 0, sizeof(*opts));
    opts->query      = QUERY_LIST;
    opts->limit      = VIEW_DEFAULT_LIMIT;
    opts->audit_path = VIEW_DEFAULT_AUDIT_LOG;
    for (ii = 1; ii < argc; ii++)
    {
        if (strcmp(argv[ii], "--header") == 0)
        {
            opts->query = QUERY_HEADER;
        }
        else if (strcmp(argv[ii], "--list") == 0)
        {
            opts->query = QUERY_LIST;
        }
        else if (ParseValueOpt(argv[ii], argv, argc, &ii, opts) != 0)
        {
            return -EINVAL;
        }
    }
    if (opts->query == QUERY_RANGE && opts->key_lo > opts->key_hi)
    {
        return -EINVAL;
    }
    return ShmToolNameValid(opts->name) ? 0 : -EINVAL;
}

/*=============================================================================
FUNCTION    : ValidateReason
DESCRIPTION : 원문 보기 사유를 검사하고 감사 로그에 안전한 형태로 옮긴다.
              제어 문자·따옴표는 '_' 로 바꾼다
RETURNED    : 0 사용 가능, -EINVAL 너무 짧거나 김
=============================================================================*/
static int ValidateReason(const char *reason, char *out, size_t out_size)
{
    size_t len = (reason == NULL) ? 0 : strlen(reason);
    size_t ii  = 0;

    if (len < VIEW_REASON_MIN_LEN || len > VIEW_REASON_MAX_LEN || len >= out_size)
    {
        return -EINVAL;
    }
    for (ii = 0; ii < len; ii++)
    {
        unsigned char ch = (unsigned char)reason[ii];

        out[ii] = (ch < 0x20 || ch == 0x7f || ch == '"') ? '_' : (char)ch;
    }
    out[len] = '\0';
    return 0;
}

static void QueryText(const ViewOpts *opts, char *out, size_t out_size)
{
    switch (opts->query)
    {
    case QUERY_KEY:   snprintf(out, out_size, "key:%u", opts->key_lo); break;
    case QUERY_RANGE: snprintf(out, out_size, "range:%u-%u", opts->key_lo, opts->key_hi); break;
    default:          snprintf(out, out_size, "list:%u", opts->limit); break;
    }
}

/*=============================================================================
FUNCTION    : WriteAuditLine
DESCRIPTION : 원문 보기 감사 한 줄(누가·언제·사유·세그먼트·조회 범위)을 O_APPEND 로 남긴다.
              기록에 실패하면 원문을 보여 주지 않는다(fail closed)
RETURNED    : 0 기록함, 음수 errno
=============================================================================*/
static int WriteAuditLine(const ViewOpts *opts, const char *reason)
{
    char    line[VIEW_AUDIT_LINE_MAX];
    char    user[TOOL_USER_MAX];
    char    now[40];
    char    query[VIEW_QUERY_TEXT_MAX];
    int     len = 0;
    int     fd  = -1;
    ssize_t written = 0;

    ShmToolUserName(user, sizeof(user));
    ShmToolNowText(now, sizeof(now));
    QueryText(opts, query, sizeof(query));
    len = snprintf(line, sizeof(line),
                   "ts=%s user=%s uid=%ld pid=%ld action=unmask segment=%s query=%s reason=\"%s\"\n",
                   now, user, (long)getuid(), (long)getpid(), opts->name, query, reason);
    if (len < 0 || (size_t)len >= sizeof(line))
    {
        return -EOVERFLOW;
    }
    fd = open(opts->audit_path, O_WRONLY | O_CREAT | O_APPEND, 0600);
    if (fd < 0)
    {
        return -errno;
    }
    written = write(fd, line, (size_t)len);    /* 한 줄 한 번의 write — 다중 프로세스 O_APPEND */
    if (written != len)
    {
        int saved_errno = (written < 0) ? errno : EIO;

        close(fd);
        return -saved_errno;
    }
    return (close(fd) == 0) ? 0 : -errno;
}

static int ColumnWidth(const FieldDef *def)
{
    int width = 0;

    switch (def->kind)
    {
    case FIELD_KIND_U32:   width = 10; break;
    case FIELD_KIND_HEX32: width = 10; break;
    case FIELD_KIND_I64:   width = 20; break;
    default:               width = (int)def->size; break;
    }
    return ((int)strlen(def->name) > width) ? (int)strlen(def->name) : width;
}

static void PrintHeaderRow(bool is_csv)
{
    size_t ii    = 0;
    bool   first = true;

    for (ii = 0; ii < g_ItemFieldCnt; ii++)
    {
        const FieldDef *def = &g_ItemFieldDefs[ii];

        if (!FieldIsPrintable(def))
        {
            continue;
        }
        if (is_csv) { printf("%s%s", first ? "" : ",", def->name); }
        else        { printf("%s%-*s", first ? "" : " | ", ColumnWidth(def), def->name); }
        first = false;
    }
    printf("\n");
}

static void PrintRecord(const ItemRec *rec, bool is_csv, bool unmask)
{
    char   cell[FIELD_TEXT_MAX];
    size_t ii    = 0;
    bool   first = true;

    for (ii = 0; ii < g_ItemFieldCnt; ii++)
    {
        const FieldDef *def = &g_ItemFieldDefs[ii];

        if (!FieldIsPrintable(def))
        {
            continue;
        }
        FieldFormat(def, rec, unmask, cell, sizeof(cell));
        if (is_csv) { printf("%s%s", first ? "" : ",", cell); }
        else        { printf("%s%-*s", first ? "" : " | ", ColumnWidth(def), cell); }
        first = false;
    }
    printf("\n");
}

static int PrintHeaderOnly(const ViewOpts *opts)
{
    ShmHdr    peek;
    ShmLayout layout;
    int       ret = ShmSegPeekHdr(opts->name, &peek);

    if (ret != 0)
    {
        fprintf(stderr, "[shm_view] 세그먼트를 열 수 없다: %s (%s)\n", opts->name, strerror(-ret));
        return TOOL_EXIT_ERROR;
    }
    ShmToolPrintHdr(stdout, opts->name, &peek);
    if (ShmToolLayout(&peek, opts->cap, &layout) != 0)
    {
        printf("header_check=bad rc=%d\n", -EINVAL);
        return TOOL_EXIT_CORRUPT;
    }
    ret = ShmHdrCheck(&peek, &layout, ShmSegCalcSize(&layout), SHM_ATTACH_ALLOW_CORRUPT);
    printf("header_check=%s rc=%d\n", ret == 0 ? "ok" : "bad", ret);
    return (ret == 0) ? TOOL_EXIT_OK : TOOL_EXIT_CORRUPT;
}

/*=============================================================================
FUNCTION    : TakeSnapshot
DESCRIPTION : 읽기 전용으로 attach 해 레코드 영역을 지역 버퍼로 복사한다. 읽기 전용 매핑은
              락을 잡을 수 없으므로 작성 중인 값이 섞일 수 있다 — 상태가 READY 가 아니면 경고한다.
              SysV 세그먼트를 쓰는 프로젝트는 같은 자리에서 shmat(id, NULL, SHM_RDONLY) 로 붙는다
PARAMETERS  : const ViewOpts *opts - 옵션
              ItemRec **out_recs   - 복사본(호출자가 free)
              uint32_t *out_cnt    - 건수
RETURNED    : 0 성공, 음수 errno
=============================================================================*/
static int TakeSnapshot(const ViewOpts *opts, ItemRec **out_recs, uint32_t *out_cnt)
{
    ShmHdr    peek;
    ShmLayout layout;
    ShmSeg   *seg = NULL;
    ItemRec  *recs = NULL;
    uint32_t  cnt = 0;
    int       ret = ShmSegPeekHdr(opts->name, &peek);

    ret = (ret == 0) ? ShmToolLayout(&peek, opts->cap, &layout) : ret;
    ret = (ret == 0) ? ShmSegAttach(opts->name, &layout,
                                    SHM_ATTACH_RDONLY | SHM_ATTACH_ALLOW_CORRUPT, &seg) : ret;
    if (ret != 0)
    {
        return ret;
    }
    if (!ShmSegIsReady(seg))
    {
        fprintf(stderr, "[shm_view] 경고: 상태가 %s — 내용이 일관되지 않을 수 있다\n",
                ShmToolStateName(atomic_load(&ShmSegHdr(seg)->state)));
    }
    cnt = ShmSegHdr(seg)->rec_cnt;
    if (cnt > layout.rec_cap)
    {
        ShmSegDetach(seg);      /* attach 뒤에 건수가 깨졌다 — 매핑 밖을 읽지 않는다 */
        return -EBADMSG;
    }
    recs = calloc(cnt ? cnt : 1, sizeof(ItemRec));
    if (recs == NULL)
    {
        ShmSegDetach(seg);
        return -ENOMEM;
    }
    memcpy(recs, ShmSegData(seg), (size_t)cnt * sizeof(ItemRec));
    ShmSegDetach(seg);
    *out_recs = recs;
    *out_cnt  = cnt;
    return 0;
}

static int PrintRecords(const ViewOpts *opts, bool unmask)
{
    ItemRec  *recs  = NULL;
    uint32_t  cnt   = 0;
    uint32_t  first = 0;
    int       found = 0;
    int       ret   = TakeSnapshot(opts, &recs, &cnt);
    ItemTable tbl;
    uint32_t  ii    = 0;

    if (ret != 0)
    {
        fprintf(stderr, "[shm_view] attach 실패: %s (%s)\n", opts->name, strerror(-ret));
        return TOOL_EXIT_ERROR;
    }
    ItemTableBind(&tbl, recs, &cnt, cnt);
    if (ItemTableCheckSorted(&tbl) != 0)
    {
        fprintf(stderr, "[shm_view] 경고: 정렬 불변식 위반 — 키·범위 조회 결과를 믿을 수 없다\n");
    }
    switch (opts->query)
    {
    case QUERY_KEY:
        found = ItemTableFind(&tbl, opts->key_lo);
        first = (found >= 0) ? (uint32_t)found : 0;
        found = (found >= 0) ? 1 : 0;
        break;
    case QUERY_RANGE:
        found = ItemTableFindRange(&tbl, opts->key_lo, opts->key_hi, &first);
        break;
    default:
        found = (int)(cnt < opts->limit ? cnt : opts->limit);
        break;
    }
    PrintHeaderRow(opts->is_csv);
    for (ii = 0; ii < (uint32_t)(found > 0 ? found : 0); ii++)
    {
        PrintRecord(&recs[first + ii], opts->is_csv, unmask);
    }
    fflush(stdout);     /* 요약(표준 에러)이 표 뒤에 오게 한다 */
    fprintf(stderr, "[shm_view] rows=%d total=%u masked=%s\n", found, cnt, unmask ? "no" : "yes");
    free(recs);
    return (found > 0 || opts->query == QUERY_LIST) ? TOOL_EXIT_OK : TOOL_EXIT_ERROR;
}

int main(int argc, char **argv)
{
    ViewOpts opts;
    char     reason[VIEW_REASON_MAX_LEN + 1];
    int      ret = 0;

    if (ParseOpts(argc, argv, &opts) != 0)
    {
        PrintUsage();
        return TOOL_EXIT_ERROR;
    }
    if (opts.query == QUERY_HEADER)
    {
        return PrintHeaderOnly(&opts);
    }
    if (opts.unmask_reason != NULL)
    {
        if (ValidateReason(opts.unmask_reason, reason, sizeof(reason)) != 0)
        {
            fprintf(stderr, "[shm_view] --unmask 사유는 %u~%u자로 적는다\n",
                    VIEW_REASON_MIN_LEN, VIEW_REASON_MAX_LEN);
            return TOOL_EXIT_REFUSED;
        }
        ret = WriteAuditLine(&opts, reason);
        if (ret != 0)
        {
            fprintf(stderr, "[shm_view] 감사 로그 기록 실패(%s) — 원문 보기를 거부한다\n",
                    strerror(-ret));
            return TOOL_EXIT_REFUSED;
        }
    }
    return PrintRecords(&opts, opts.unmask_reason != NULL);
}
