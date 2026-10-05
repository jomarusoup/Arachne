/*#############################################################################
FILE NAME   : rec_loader.h
DESCRIPTION : 복구 원천 적재 인터페이스 — Open·FetchBatch·Close 함수 포인터 테이블
#############################################################################*/
#ifndef REC_LOADER_H
#define REC_LOADER_H

#include <stdint.h>

#include "sorted_table.h"

/*-----------------------------------------------------------------------------
원천(DB·파일)에서 품목 레코드를 묶음 단위로 읽는다. 구현마다 static const 테이블
하나를 두고, 복구 도구는 이 테이블만 통해 부른다(불투명 핸들 + ops 테이블 패턴).
  Open       : src 를 열고 구현 상태를 *out_impl 에 돌려준다. 0 성공, 음수 errno
  FetchBatch : buf 에 최대 max_cnt 건을 채운다. 읽은 건수(0 이면 끝), 음수 errno
  Close      : 구현 상태를 해제한다. NULL 허용
-----------------------------------------------------------------------------*/
typedef struct RecLoaderOps
{
    const char *kind;
    int       (*Open)(const char *src, void **out_impl);
    int       (*FetchBatch)(void *impl, ItemRec *buf, uint32_t max_cnt);
    void      (*Close)(void *impl);
} RecLoaderOps;

/* 파일 원천 — 확장자 .csv 는 CSV, 그 밖은 ItemRec 고정 크기 바이너리(같은 빌드의 바이트 순서) */
extern const RecLoaderOps g_FileLoaderOps;

/* DB 원천 — Pro*C 호스트 배열 fetch 가 들어갈 자리. 이 저장소 빌드에서는 -ENOTSUP */
extern const RecLoaderOps g_DbLoaderOps;

/*=============================================================================
FUNCTION    : RecLoaderSelect
DESCRIPTION : "file:<경로>" 또는 "db:<접속 별칭>" 형식의 원천 지정을 해석한다
PARAMETERS  : const char *spec     - 원천 지정 문자열
              const char **out_src - 접두를 뗀 원천 문자열
RETURNED    : 구현 테이블, 형식이 틀리면 NULL
=============================================================================*/
const RecLoaderOps *RecLoaderSelect(const char *spec, const char **out_src);

#endif /* REC_LOADER_H */
