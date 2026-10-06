/*#############################################################################
FILE NAME   : item_field.h
DESCRIPTION : 품목 레코드 필드 정의 표(X-매크로 생성)와 필드 단위 출력·마스킹 API
#############################################################################*/
#ifndef ITEM_FIELD_H
#define ITEM_FIELD_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#include "sorted_table.h"

/* 출력 종류 — ITEM_FIELD_LIST 의 두 번째 인자와 이름이 맞물린다 */
typedef enum FieldKind
{
    FIELD_KIND_U32,
    FIELD_KIND_I64,
    FIELD_KIND_HEX32,
    FIELD_KIND_TEXT,
    FIELD_KIND_PAD,     /* 명시 패딩 — 출력하지 않는다 */
} FieldKind;

/* 마스킹 방식 — ITEM_FIELD_LIST 의 세 번째 인자와 이름이 맞물린다 */
typedef enum FieldMask
{
    FIELD_MASK_NONE,
    FIELD_MASK_ALL,     /* LogMaskAll — 값 전체를 "****" 로 */
    FIELD_MASK_DIGITS,  /* LogMaskDigits — 마지막 4자리만 남김 */
} FieldMask;

typedef struct FieldDef
{
    const char *name;
    size_t      offset;
    size_t      size;
    FieldKind   kind;
    FieldMask   mask;
} FieldDef;

#define FIELD_TEXT_MAX  128u    /* 필드 하나의 출력 문자열 최대 길이(NUL 포함) */

extern const FieldDef g_ItemFieldDefs[];
extern const size_t   g_ItemFieldCnt;

/*=============================================================================
FUNCTION    : FieldFormat
DESCRIPTION : 레코드의 필드 하나를 문자열로 만든다. 마스킹 대상이면 unmask 가
              false 일 때 가린 값만 내놓는다. 출력할 수 없는 문자는 '?' 로 바꾼다
PARAMETERS  : const FieldDef *def - 필드 정의
              const ItemRec *rec  - 레코드
              bool unmask         - true 면 원문(호출자가 감사 기록을 마친 뒤에만)
              char *out           - 결과 버퍼(FIELD_TEXT_MAX 이상 권장)
              size_t out_size     - 결과 버퍼 크기
RETURNED    : out
=============================================================================*/
char *FieldFormat(const FieldDef *def, const ItemRec *rec, bool unmask,
                  char *out, size_t out_size);

/* PAD 필드는 출력 대상이 아니다 */
bool FieldIsPrintable(const FieldDef *def);

#endif /* ITEM_FIELD_H */
