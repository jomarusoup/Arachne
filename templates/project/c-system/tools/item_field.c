/*#############################################################################
FILE NAME   : item_field.c
DESCRIPTION : ITEM_FIELD_LIST X-매크로로 필드 정의 표를 만들고 필드 단위 출력·마스킹을 한다
#############################################################################*/
#define _POSIX_C_SOURCE 200809L

/* 1. 표준 라이브러리 */
#include <inttypes.h>
#include <stdio.h>
#include <string.h>

/* 4. 프로젝트 내부 헤더 */
#include "item_field.h"
#include "log.h"

/*-----------------------------------------------------------------------------
필드 정의 표 — 레이아웃 헤더의 목록을 그대로 펼친다(D14 X-매크로 예외).
레코드 필드가 바뀌면 이 표는 다시 컴파일될 때 자동으로 따라간다.
-----------------------------------------------------------------------------*/
#define ITEM_FIELD_DEF(fname, fkind, fmask)                                   \
    { #fname, offsetof(ItemRec, fname), sizeof(((ItemRec *)0)->fname),        \
      FIELD_KIND_##fkind, FIELD_MASK_##fmask },

const FieldDef g_ItemFieldDefs[] =
{
    ITEM_FIELD_LIST(ITEM_FIELD_DEF)
};

const size_t g_ItemFieldCnt = sizeof(g_ItemFieldDefs) / sizeof(g_ItemFieldDefs[0]);

/* 목록이 레코드의 모든 바이트를 덮는지 컴파일 시점에 검사한다 — 필드 누락 방지 */
#define ITEM_FIELD_SIZE(fname, fkind, fmask) + sizeof(((ItemRec *)0)->fname)

_Static_assert(0 ITEM_FIELD_LIST(ITEM_FIELD_SIZE) == sizeof(ItemRec),
               "ITEM_FIELD_LIST 가 ItemRec 필드와 맞지 않는다 — 목록을 고친다");

bool FieldIsPrintable(const FieldDef *def)
{
    return def->kind != FIELD_KIND_PAD;
}

/*=============================================================================
FUNCTION    : FormatRaw
DESCRIPTION : 마스킹 전 원문 문자열을 만든다
=============================================================================*/
static void FormatRaw(const FieldDef *def, const uint8_t *base, char *out, size_t out_size)
{
    uint32_t u32 = 0;
    int64_t  i64 = 0;
    size_t   ii  = 0;
    size_t   len = 0;

    switch (def->kind)
    {
    case FIELD_KIND_U32:
        memcpy(&u32, base + def->offset, sizeof(u32));
        snprintf(out, out_size, "%" PRIu32, u32);
        break;
    case FIELD_KIND_HEX32:
        memcpy(&u32, base + def->offset, sizeof(u32));
        snprintf(out, out_size, "0x%08" PRIx32, u32);
        break;
    case FIELD_KIND_I64:
        memcpy(&i64, base + def->offset, sizeof(i64));
        snprintf(out, out_size, "%" PRId64, i64);
        break;
    case FIELD_KIND_TEXT:
        /* 고정 길이 — NUL 이 없을 수 있다. 제어 문자·구분자는 '?' 로 바꾼다 */
        len = def->size < out_size - 1 ? def->size : out_size - 1;
        for (ii = 0; ii < len && base[def->offset + ii] != '\0'; ii++)
        {
            uint8_t ch = base[def->offset + ii];

            out[ii] = (ch < 0x20 || ch == 0x7f || ch == ',' || ch == '"') ? '?' : (char)ch;
        }
        out[ii] = '\0';
        break;
    case FIELD_KIND_PAD:
    default:
        out[0] = '\0';
        break;
    }
}

char *FieldFormat(const FieldDef *def, const ItemRec *rec, bool unmask,
                  char *out, size_t out_size)
{
    char raw[FIELD_TEXT_MAX];

    if (out == NULL || out_size == 0)
    {
        return out;
    }
    FormatRaw(def, (const uint8_t *)rec, raw, sizeof(raw));
    if (unmask || def->mask == FIELD_MASK_NONE)
    {
        snprintf(out, out_size, "%s", raw);
    }
    else if (def->mask == FIELD_MASK_DIGITS)
    {
        LogMaskDigits(raw, out, out_size);
    }
    else
    {
        LogMaskAll(raw, out, out_size);
    }
    return out;
}
