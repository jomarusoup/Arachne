/*#############################################################################
FILE NAME   : shm_tool.c
DESCRIPTION : 운영 도구 공용 구현 — 이름 검사·레이아웃 결정·헤더 출력·attach 프로세스 수
#############################################################################*/
#define _POSIX_C_SOURCE 200809L

/* 1. 표준 라이브러리 */
#include <ctype.h>
#include <errno.h>
#include <inttypes.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

/* 2. POSIX / 시스템 헤더 */
#include <pwd.h>
#include <unistd.h>
#ifdef __linux__
#include <dirent.h>
#endif

/* 4. 프로젝트 내부 헤더 */
#include "shm_tool.h"
#include "sorted_table.h"

#define TOOL_NAME_MAX_LEN   30u     /* "/" 제외 — macOS PSHMNAMLEN(31) 안쪽 */
#define TOOL_MAPS_LINE_MAX  4096u

bool ShmToolNameValid(const char *name)
{
    size_t len = 0;
    size_t ii  = 0;

    if (name == NULL || name[0] != '/')
    {
        return false;
    }
    len = strlen(name + 1);
    if (len == 0 || len > TOOL_NAME_MAX_LEN)
    {
        return false;
    }
    for (ii = 1; name[ii] != '\0'; ii++)
    {
        unsigned char ch = (unsigned char)name[ii];

        if (!isalnum(ch) && ch != '.' && ch != '_' && ch != '-')
        {
            return false;
        }
    }
    return true;
}

int ShmToolLayout(const ShmHdr *peek, uint32_t cap_override, ShmLayout *out)
{
    out->layout_ver = ITEM_LAYOUT_VER;
    out->rec_size   = (uint32_t)sizeof(ItemRec);
    out->rec_cap    = (cap_override != 0) ? cap_override : peek->rec_cap;
    if (out->rec_cap == 0 || ShmSegCalcSize(out) == 0)
    {
        return -EINVAL;
    }
    return 0;
}

#ifdef __linux__
/*=============================================================================
FUNCTION    : MapsHasSegment
DESCRIPTION : /proc/<pid>/maps 에 /dev/shm/<이름> 매핑이 있는지 본다
PARAMETERS  : const char *maps_path - maps 파일 경로
              const char *target    - "/dev/shm/<이름>"
RETURNED    : true 매핑 있음(읽을 수 없으면 false)
=============================================================================*/
static bool MapsHasSegment(const char *maps_path, const char *target)
{
    FILE  *fp         = fopen(maps_path, "r");
    char   line[TOOL_MAPS_LINE_MAX];
    size_t target_len = strlen(target);
    bool   is_found   = false;

    if (fp == NULL)
    {
        return false;   /* 다른 계정 프로세스 — 권한이 없으면 셀 수 없다 */
    }
    while (!is_found && fgets(line, sizeof(line), fp) != NULL)
    {
        char *hit = strstr(line, target);

        /* 경로 뒤는 줄 끝 또는 " (deleted)" 여야 한다(접두 일치 오탐 방지) */
        if (hit != NULL &&
            (hit[target_len] == '\n' || hit[target_len] == '\0' || hit[target_len] == ' '))
        {
            is_found = true;
        }
    }
    fclose(fp);
    return is_found;
}
#endif

int ShmToolAttachCount(const char *name)
{
#ifdef __linux__
    DIR           *dir      = NULL;
    struct dirent *ent      = NULL;
    char           target[64];
    char           maps_path[64];
    long           self_pid = (long)getpid();
    int            cnt      = 0;

    snprintf(target, sizeof(target), "/dev/shm/%s", name + 1);
    dir = opendir("/proc");
    if (dir == NULL)
    {
        return -errno;
    }
    while ((ent = readdir(dir)) != NULL)
    {
        char *end = NULL;
        long  pid = strtol(ent->d_name, &end, 10);

        if (*end != '\0' || pid <= 0 || pid == self_pid)
        {
            continue;
        }
        snprintf(maps_path, sizeof(maps_path), "/proc/%ld/maps", pid);
        if (MapsHasSegment(maps_path, target))
        {
            cnt++;
        }
    }
    closedir(dir);
    return cnt;
#else
    /* macOS 는 POSIX 공유메모리 매핑을 프로세스별로 볼 방법이 없다 */
    (void)name;
    return -ENOTSUP;
#endif
}

const char *ShmToolStateName(uint32_t state)
{
    switch (state)
    {
    case SHM_STATE_INIT:       return "INIT";
    case SHM_STATE_READY:      return "READY";
    case SHM_STATE_RECOVERING: return "RECOVERING";
    case SHM_STATE_CORRUPT:    return "CORRUPT";
    default:                   return "UNKNOWN";
    }
}

void ShmToolPrintHdr(FILE *out, const char *name, const ShmHdr *hdr)
{
    uint32_t magic = atomic_load(&hdr->magic);
    uint32_t state = atomic_load(&hdr->state);

    fprintf(out, "segment=%s\n", name);
    fprintf(out, "magic=0x%08" PRIx32 " (%s)\n", magic,
            magic == SHM_MAGIC ? "ok" : (magic == 0 ? "init" : "bad"));
    fprintf(out, "layout_ver=%" PRIu32 " (expect %u)\n", hdr->layout_ver, ITEM_LAYOUT_VER);
    fprintf(out, "rec_size=%" PRIu32 " (expect %zu)\n", hdr->rec_size, sizeof(ItemRec));
    fprintf(out, "rec_cap=%" PRIu32 "\n", hdr->rec_cap);
    fprintf(out, "rec_cnt=%" PRIu32 "\n", hdr->rec_cnt);
    fprintf(out, "state=%s(%" PRIu32 ")\n", ShmToolStateName(state), state);
    fprintf(out, "created_ts=%" PRId64 "\n", hdr->created_ts);
    fprintf(out, "load_seq=%" PRIu64 "\n", hdr->load_seq);
    fprintf(out, "checksum=0x%016" PRIx64 "\n", hdr->checksum);
}

void ShmToolUserName(char *out, size_t out_size)
{
    struct passwd *pw = getpwuid(getuid());

    if (pw != NULL && pw->pw_name != NULL)
    {
        snprintf(out, out_size, "%s", pw->pw_name);
    }
    else
    {
        snprintf(out, out_size, "uid%ld", (long)getuid());
    }
}

void ShmToolNowText(char *out, size_t out_size)
{
    time_t    now = time(NULL);
    struct tm tm_local;

    if (localtime_r(&now, &tm_local) == NULL ||
        strftime(out, out_size, "%Y-%m-%dT%H:%M:%S%z", &tm_local) == 0)
    {
        snprintf(out, out_size, "%ld", (long)now);
    }
}
