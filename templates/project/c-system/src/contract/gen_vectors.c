/*#############################################################################
FILE NAME   : gen_vectors.c
DESCRIPTION : C 헤더 정본에서 레이아웃 매니페스트(layout.json)·바이너리 테스트 벡터(*.bin)·기댓값(cases.json)을 생성
#############################################################################*/

#include <errno.h>
#include <inttypes.h>
#include <stdio.h>
#include <string.h>

#include "stream_msg.h"

/*-----------------------------------------------------------------------------
매니페스트 필드 표 — 오프셋·크기는 컴파일러가 계산한 offsetof·sizeof 에서 가져온다.
손으로 숫자를 적지 않으므로 구조체가 바뀌면 매니페스트가 따라 바뀌고 CI diff 가 잡는다.
-----------------------------------------------------------------------------*/
typedef struct FieldDesc
{
    const char *name;
    size_t      offset;
    size_t      size;
    const char *type;
} FieldDesc;

/*-----------------------------------------------------------------------------
필드 정의 X-매크로 표 (D14 예외) — 항목: 구조체, 멤버, JSON 이름, 와이어 타입
-----------------------------------------------------------------------------*/
#define HEADER_FIELDS(X) \
    X(StreamMsgHeader, version,      "version",    "u16") \
    X(StreamMsgHeader, msg_type,     "msgType",    "u16") \
    X(StreamMsgHeader, body_len,     "bodyLen",    "u32") \
    X(StreamMsgHeader, sequence,     "sequence",   "u64") \
    X(StreamMsgHeader, send_time_ns, "sendTimeNs", "i64")

#define QUOTE_FIELDS(X) \
    X(StreamQuote, key,      "key",      "ascii-nul-padded") \
    X(StreamQuote, price,    "price",    "i64") \
    X(StreamQuote, qty,      "qty",      "i64") \
    X(StreamQuote, flags,    "flags",    "u32") \
    X(StreamQuote, reserved, "reserved", "reserved")

#define FIELD_DESC(type, member, json_name, wire_type) \
    { (json_name), offsetof(type, member), sizeof(((type *)0)->member), (wire_type) },

static const FieldDesc g_HeaderFields[] = { HEADER_FIELDS(FIELD_DESC) };
static const FieldDesc g_QuoteFields[]  = { QUOTE_FIELDS(FIELD_DESC) };

static const size_t g_HeaderFieldCnt = sizeof(g_HeaderFields) / sizeof(g_HeaderFields[0]);
static const size_t g_QuoteFieldCnt  = sizeof(g_QuoteFields) / sizeof(g_QuoteFields[0]);

/*-----------------------------------------------------------------------------
테스트 벡터 정의 — 경계값을 일부러 넣는다
- quote_basic    : 평범한 값
- quote_extreme  : 2^53 을 넘는 정수, INT64_MIN·INT64_MAX, 16자를 꽉 채운 키, 최대 시퀀스
- quote_extended : 미래 버전이 본문 끝에 8바이트를 덧붙인 메시지 — v1 은 무시해야 한다
- heartbeat      : 본문 없음
-----------------------------------------------------------------------------*/
typedef struct QuoteCase
{
    const char *file;
    uint64_t    sequence;
    int64_t     send_time_ns;
    const char *key;
    int64_t     price;
    int64_t     qty;
    uint32_t    flags;
    size_t      extra_len;      /* 본문 뒤에 덧붙일 미래 필드 바이트 수 */
} QuoteCase;

static const QuoteCase g_QuoteCases[] = {
    { "quote_basic.bin",    1, INT64_C(1790000000123456789), "ALPHA",
      1234500, 10000, 0x1u, 0 },
    { "quote_extreme.bin",  UINT64_MAX, INT64_C(9007199254740993), "ABCDEFGHIJKLMNOP",
      INT64_MIN, INT64_MAX, 0xFFFFFFFFu, 0 },
    { "quote_extended.bin", 3, INT64_C(1790000000999999999), "BETA-2",
      -250000, 1, 0x2u, 8 },
};

static const size_t g_QuoteCaseCnt = sizeof(g_QuoteCases) / sizeof(g_QuoteCases[0]);

/*-----------------------------------------------------------------------------
파일 쓰기 — 경로는 "<디렉터리>/<이름>"
-----------------------------------------------------------------------------*/
static FILE *OpenOut(const char *dir, const char *name)
{
    char path[1024];
    int  len;

    len = snprintf(path, sizeof(path), "%s/%s", dir, name);
    if (len < 0 || (size_t)len >= sizeof(path))
    {
        fprintf(stderr, "[gen_vectors] 경로가 너무 길다: %s/%s\n", dir, name);
        return NULL;
    }
    return fopen(path, "wb");
}

static int WriteFile(const char *dir, const char *name, const uint8_t *data, size_t len)
{
    FILE *fp = OpenOut(dir, name);
    int   ret = 0;

    if (fp == NULL)
    {
        return -errno;
    }
    if (len > 0 && fwrite(data, 1, len, fp) != len)
    {
        ret = -EIO;
    }
    if (fclose(fp) != 0 && ret == 0)
    {
        ret = -EIO;
    }
    return ret;
}

static void PrintFields(FILE *fp, const FieldDesc *fields, size_t count)
{
    size_t ii;

    for (ii = 0; ii < count; ii++)
    {
        fprintf(fp, "        { \"name\": \"%s\", \"offset\": %zu, \"size\": %zu, \"type\": \"%s\" }%s\n",
                fields[ii].name, fields[ii].offset, fields[ii].size, fields[ii].type,
                ii + 1 < count ? "," : "");
    }
}

/*-----------------------------------------------------------------------------
layout.json — 레이아웃 드리프트 검출용 매니페스트. JSON 키는 camelCase.
-----------------------------------------------------------------------------*/
static int WriteLayout(const char *dir)
{
    FILE *fp = OpenOut(dir, "layout.json");

    if (fp == NULL)
    {
        return -errno;
    }

    fprintf(fp, "{\n");
    fprintf(fp, "  \"schema\": \"stream_msg\",\n");
    fprintf(fp, "  \"version\": %u,\n", STREAM_MSG_VERSION);
    fprintf(fp, "  \"endian\": \"little\",\n");
    fprintf(fp, "  \"maxBody\": %u,\n", STREAM_MSG_MAX_BODY);
    fprintf(fp, "  \"priceScale\": %d,\n", STREAM_PRICE_SCALE);
    fprintf(fp, "  \"qtyScale\": %d,\n", STREAM_QTY_SCALE);
    fprintf(fp, "  \"msgTypes\": { \"heartbeat\": %u, \"quote\": %u },\n",
            STREAM_MSG_TYPE_HEARTBEAT, STREAM_MSG_TYPE_QUOTE);
    fprintf(fp, "  \"structs\": {\n");
    fprintf(fp, "    \"StreamMsgHeader\": {\n      \"size\": %zu,\n      \"fields\": [\n",
            sizeof(StreamMsgHeader));
    PrintFields(fp, g_HeaderFields, g_HeaderFieldCnt);
    fprintf(fp, "      ]\n    },\n");
    fprintf(fp, "    \"StreamQuote\": {\n      \"size\": %zu,\n      \"fields\": [\n",
            sizeof(StreamQuote));
    PrintFields(fp, g_QuoteFields, g_QuoteFieldCnt);
    fprintf(fp, "      ]\n    }\n  }\n}\n");

    return fclose(fp) == 0 ? 0 : -EIO;
}

/*-----------------------------------------------------------------------------
LE32 로 body_len 을 덮어쓴다 — 미래 버전 메시지를 흉내 낼 때만 쓴다
-----------------------------------------------------------------------------*/
static void PatchBodyLen(uint8_t *msg, uint32_t body_len)
{
    int ii;

    for (ii = 0; ii < 4; ii++)
    {
        msg[offsetof(StreamMsgHeader, body_len) + ii] = (uint8_t)(body_len >> (8 * ii));
    }
}

/*-----------------------------------------------------------------------------
벡터 하나를 인코딩해 파일로 쓰고, 기댓값을 cases.json 에 한 줄 추가한다.
JSON 에서 64비트 정수는 문자열로 적는다 — JS Number 정밀도(2^53) 경계 때문이다.
-----------------------------------------------------------------------------*/
static int WriteQuoteCase(const char *dir, const QuoteCase *qc, FILE *cases, int is_last)
{
    uint8_t         buf[STREAM_HEADER_SIZE + STREAM_QUOTE_SIZE + 16];
    StreamMsgHeader hdr;
    StreamQuote     quote;
    ssize_t         len;
    size_t          ii;
    int             ret;

    memset(&hdr, 0, sizeof(hdr));
    memset(&quote, 0, sizeof(quote));
    hdr.sequence     = qc->sequence;
    hdr.send_time_ns = qc->send_time_ns;
    ret = StreamQuoteSetKey(&quote, qc->key);
    if (ret < 0)
    {
        return ret;
    }
    quote.price = qc->price;
    quote.qty   = qc->qty;
    quote.flags = qc->flags;

    len = StreamMsgEncodeQuote(&hdr, &quote, buf, sizeof(buf));
    if (len < 0)
    {
        return (int)len;
    }
    if (qc->extra_len > sizeof(buf) - (size_t)len)
    {
        return -ENOSPC;     /* 벡터 표에 큰 꼬리를 넣으면 buf 를 늘린다 */
    }
    for (ii = 0; ii < qc->extra_len; ii++)
    {
        buf[(size_t)len + ii] = (uint8_t)(0xA0 + ii);   /* 0 이 아닌 값 — 무시되는지 확인용 */
    }
    if (qc->extra_len > 0)
    {
        PatchBodyLen(buf, (uint32_t)(STREAM_QUOTE_SIZE + qc->extra_len));
    }

    ret = WriteFile(dir, qc->file, buf, (size_t)len + qc->extra_len);
    if (ret < 0)
    {
        return ret;
    }

    fprintf(cases,
            "    { \"file\": \"%s\", \"msgType\": %u, \"bodyLen\": %zu, "
            "\"sequence\": \"%" PRIu64 "\", \"sendTimeNs\": \"%" PRId64 "\",\n"
            "      \"quote\": { \"key\": \"%s\", \"price\": \"%" PRId64 "\", "
            "\"qty\": \"%" PRId64 "\", \"flags\": %" PRIu32 " } }%s\n",
            qc->file, STREAM_MSG_TYPE_QUOTE, STREAM_QUOTE_SIZE + qc->extra_len,
            qc->sequence, qc->send_time_ns, qc->key, qc->price, qc->qty, qc->flags,
            is_last ? "" : ",");
    return 0;
}

static int WriteVectors(const char *dir)
{
    uint8_t         buf[STREAM_HEADER_SIZE];
    StreamMsgHeader hdr;
    FILE           *cases;
    ssize_t         len;
    size_t          ii;
    int             ret = 0;

    cases = OpenOut(dir, "cases.json");
    if (cases == NULL)
    {
        return -errno;
    }
    fprintf(cases, "{\n  \"version\": %u,\n  \"cases\": [\n", STREAM_MSG_VERSION);

    /*-------------------------------------------------------------------------
    하트비트
    -------------------------------------------------------------------------*/
    memset(&hdr, 0, sizeof(hdr));
    hdr.sequence     = 2;
    hdr.send_time_ns = INT64_C(1790000000500000000);
    len = StreamMsgEncodeHeartbeat(&hdr, buf, sizeof(buf));
    if (len < 0)
    {
        ret = (int)len;
        goto cleanup;
    }
    ret = WriteFile(dir, "heartbeat.bin", buf, (size_t)len);
    if (ret < 0)
    {
        goto cleanup;
    }
    fprintf(cases,
            "    { \"file\": \"heartbeat.bin\", \"msgType\": %u, \"bodyLen\": 0, "
            "\"sequence\": \"%" PRIu64 "\", \"sendTimeNs\": \"%" PRId64 "\" },\n",
            STREAM_MSG_TYPE_HEARTBEAT, hdr.sequence, hdr.send_time_ns);

    for (ii = 0; ii < g_QuoteCaseCnt; ii++)
    {
        ret = WriteQuoteCase(dir, &g_QuoteCases[ii], cases, ii + 1 == g_QuoteCaseCnt);
        if (ret < 0)
        {
            goto cleanup;
        }
    }
    fprintf(cases, "  ]\n}\n");

cleanup:
    if (fclose(cases) != 0 && ret == 0)
    {
        ret = -EIO;
    }
    return ret;
}

int main(int argc, char **argv)
{
    const char *dir = "vectors";
    int         ret;

    if (argc > 2)
    {
        fprintf(stderr, "사용법: %s [출력 디렉터리]\n", argv[0]);
        return 2;
    }
    if (argc == 2)
    {
        dir = argv[1];
    }

    ret = WriteLayout(dir);
    if (ret == 0)
    {
        ret = WriteVectors(dir);
    }
    if (ret < 0)
    {
        fprintf(stderr, "[gen_vectors] 생성 실패: %s\n", strerror(-ret));
        return 1;
    }
    return 0;
}
