/*#############################################################################
FILE NAME   : rec_loader_file.c
DESCRIPTION : 파일 원천 적재 구현(CSV·고정 크기 바이너리) — 테스트·DB 없는 환경의 복구 원천
#############################################################################*/
#define _POSIX_C_SOURCE 200809L

/* 1. 표준 라이브러리 */
#include <errno.h>
#include <inttypes.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* 4. 프로젝트 내부 헤더 */
#include "rec_loader.h"

#define CSV_LINE_MAX    512u
#define CSV_FIELD_CNT   7u      /* item_id,group_id,prc,qty,last_ts,name,flags */

typedef struct FileLoader
{
    FILE    *fp;
    bool     is_csv;
    uint64_t line_no;           /* CSV 오류 위치 보고용 */
} FileLoader;

static bool HasCsvExt(const char *path)
{
    size_t len = strlen(path);

    return len > 4 && strcmp(path + len - 4, ".csv") == 0;
}

static int FileOpen(const char *src, void **out_impl)
{
    FileLoader *loader = NULL;

    if (src == NULL || src[0] == '\0' || out_impl == NULL)
    {
        return -EINVAL;
    }
    loader = calloc(1, sizeof(*loader));
    if (loader == NULL)
    {
        return -ENOMEM;
    }
    loader->is_csv = HasCsvExt(src);
    loader->fp     = fopen(src, loader->is_csv ? "r" : "rb");
    if (loader->fp == NULL)
    {
        int saved_errno = errno;

        free(loader);
        return -saved_errno;
    }
    *out_impl = loader;
    return 0;
}

/*=============================================================================
FUNCTION    : ParseU64
DESCRIPTION : 부호 없는 정수 토큰을 상한 안에서 해석한다
PARAMETERS  : int base - 10(키·숫자), 0(flags — 0x 접두 16진 허용)
RETURNED    : 0 성공, -EINVAL 형식·범위 오류
=============================================================================*/
static int ParseU64(const char *tok, int base, uint64_t max_val, uint64_t *out)
{
    char              *end = NULL;
    unsigned long long val = 0;

    if (tok == NULL || tok[0] == '\0' || tok[0] == '-')
    {
        return -EINVAL;
    }
    errno = 0;
    val   = strtoull(tok, &end, base);
    if (errno != 0 || *end != '\0' || val > max_val)
    {
        return -EINVAL;
    }
    *out = (uint64_t)val;
    return 0;
}

static int ParseI64(const char *tok, int64_t *out)
{
    char     *end = NULL;
    long long val = 0;

    if (tok == NULL || tok[0] == '\0')
    {
        return -EINVAL;
    }
    errno = 0;
    val   = strtoll(tok, &end, 10);
    if (errno != 0 || *end != '\0')
    {
        return -EINVAL;
    }
    *out = (int64_t)val;
    return 0;
}

/*=============================================================================
FUNCTION    : ParseCsvLine
DESCRIPTION : CSV 한 줄(item_id,group_id,prc,qty,last_ts,name,flags)을 레코드로 바꾼다.
              name 은 따옴표·쉼표 없이 1~ITEM_NAME_LEN 바이트(빈 칸은 허용하지 않는다)
RETURNED    : 0 성공, -EINVAL 형식 오류
=============================================================================*/
static int ParseCsvLine(char *line, ItemRec *rec)
{
    char    *tok[CSV_FIELD_CNT];
    char    *save = NULL;
    char    *cur  = NULL;
    uint64_t u64  = 0;
    uint32_t ii   = 0;
    int      bad  = 0;

    line[strcspn(line, "\r\n")] = '\0';
    for (cur = strtok_r(line, ",", &save); cur != NULL && ii < CSV_FIELD_CNT;
         cur = strtok_r(NULL, ",", &save))
    {
        tok[ii++] = cur;
    }
    if (ii != CSV_FIELD_CNT || cur != NULL || strlen(tok[5]) > ITEM_NAME_LEN)
    {
        return -EINVAL;
    }
    memset(rec, 0, sizeof(*rec));
    bad |= ParseU64(tok[0], 10, UINT32_MAX, &u64);
    rec->item_id = (uint32_t)u64;
    bad |= ParseU64(tok[1], 10, UINT32_MAX, &u64);
    rec->group_id = (uint32_t)u64;
    bad |= ParseI64(tok[2], &rec->prc);
    bad |= ParseI64(tok[3], &rec->qty);
    bad |= ParseI64(tok[4], &rec->last_ts);
    memcpy(rec->name, tok[5], strlen(tok[5]));
    bad |= ParseU64(tok[6], 0, UINT32_MAX, &u64);
    rec->flags = (uint32_t)u64;
    return (bad != 0) ? -EINVAL : 0;
}

static int FetchCsv(FileLoader *loader, ItemRec *buf, uint32_t max_cnt)
{
    char     line[CSV_LINE_MAX];
    uint32_t cnt = 0;

    while (cnt < max_cnt && fgets(line, sizeof(line), loader->fp) != NULL)
    {
        loader->line_no++;
        if (strchr(line, '\n') == NULL && !feof(loader->fp))
        {
            return -EINVAL;     /* 줄이 너무 길다 */
        }
        /* 빈 줄·주석·머리글 줄은 건너뛴다 */
        if (line[0] == '#' || line[0] == '\n' || line[0] == '\r' ||
            strncmp(line, "item_id", 7) == 0)
        {
            continue;
        }
        if (ParseCsvLine(line, &buf[cnt]) != 0)
        {
            fprintf(stderr, "[shm_recover] CSV 형식 오류: %" PRIu64 "번째 줄\n", loader->line_no);
            return -EINVAL;
        }
        cnt++;
    }
    return ferror(loader->fp) ? -EIO : (int)cnt;
}

static int FetchBinary(FileLoader *loader, ItemRec *buf, uint32_t max_cnt)
{
    size_t got = fread(buf, sizeof(ItemRec), max_cnt, loader->fp);

    if (ferror(loader->fp))
    {
        return -EIO;
    }
    /* 레코드 크기로 나누어떨어지지 않는 꼬리가 남으면 잘린 파일이다 */
    if (got < max_cnt && ftell(loader->fp) % (long)sizeof(ItemRec) != 0)
    {
        return -EBADMSG;
    }
    return (int)got;
}

static int FileFetchBatch(void *impl, ItemRec *buf, uint32_t max_cnt)
{
    FileLoader *loader = impl;

    if (loader == NULL || buf == NULL || max_cnt == 0 || max_cnt > INT32_MAX)
    {
        return -EINVAL;
    }
    return loader->is_csv ? FetchCsv(loader, buf, max_cnt) : FetchBinary(loader, buf, max_cnt);
}

static void FileClose(void *impl)
{
    FileLoader *loader = impl;

    if (loader == NULL)
    {
        return;
    }
    if (loader->fp != NULL)
    {
        fclose(loader->fp);
    }
    free(loader);
}

const RecLoaderOps g_FileLoaderOps = { "file", FileOpen, FileFetchBatch, FileClose };

const RecLoaderOps *RecLoaderSelect(const char *spec, const char **out_src)
{
    if (spec == NULL || out_src == NULL)
    {
        return NULL;
    }
    if (strncmp(spec, "file:", 5) == 0)
    {
        *out_src = spec + 5;
        return &g_FileLoaderOps;
    }
    if (strncmp(spec, "db:", 3) == 0)
    {
        *out_src = spec + 3;
        return &g_DbLoaderOps;
    }
    return NULL;
}
