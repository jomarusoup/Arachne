/*#############################################################################
FILE NAME   : stream_msg.c
DESCRIPTION : 스트림 메시지 인코드·디코드 — 필드마다 리틀엔디언으로 명시 변환해 호스트 바이트 순서와 무관하게 동작
#############################################################################*/

#include <errno.h>
#include <stdint.h>
#include <string.h>

#include "stream_msg.h"

/*-----------------------------------------------------------------------------
리틀엔디언 변환 헬퍼
바이트 단위로 처리하므로 정렬되지 않은 주소와 빅엔디언 호스트에서도 같은 결과를 낸다.
와이어 오프셋은 구조체 offsetof 에서 가져온다 — 구조체가 정본이기 때문이다.
-----------------------------------------------------------------------------*/
static void WriteLe16(uint16_t value, uint8_t *dst)
{
    dst[0] = (uint8_t)value;
    dst[1] = (uint8_t)(value >> 8);
}

static void WriteLe32(uint32_t value, uint8_t *dst)
{
    int ii;

    for (ii = 0; ii < 4; ii++)
    {
        dst[ii] = (uint8_t)(value >> (8 * ii));
    }
}

static void WriteLe64(uint64_t value, uint8_t *dst)
{
    int ii;

    for (ii = 0; ii < 8; ii++)
    {
        dst[ii] = (uint8_t)(value >> (8 * ii));
    }
}

static uint16_t ReadLe16(const uint8_t *src)
{
    return (uint16_t)(src[0] | (src[1] << 8));
}

static uint32_t ReadLe32(const uint8_t *src)
{
    uint32_t value = 0;
    int      ii;

    for (ii = 3; ii >= 0; ii--)
    {
        value = (value << 8) | src[ii];
    }
    return value;
}

static uint64_t ReadLe64(const uint8_t *src)
{
    uint64_t value = 0;
    int      ii;

    for (ii = 7; ii >= 0; ii--)
    {
        value = (value << 8) | src[ii];
    }
    return value;
}

/*-----------------------------------------------------------------------------
uint64 → int64 를 구현 정의 동작 없이 바꾼다 (2의 보수 해석)
-----------------------------------------------------------------------------*/
static int64_t U64ToI64(uint64_t value)
{
    if (value <= (uint64_t)INT64_MAX)
    {
        return (int64_t)value;
    }
    return -(int64_t)(UINT64_MAX - value) - 1;
}

/*-----------------------------------------------------------------------------
헤더 24바이트를 dst 에 쓴다
-----------------------------------------------------------------------------*/
static void WriteHeader(const StreamMsgHeader *hdr, uint16_t msg_type, uint32_t body_len,
                        uint8_t *dst)
{
    WriteLe16(STREAM_MSG_VERSION, dst + offsetof(StreamMsgHeader, version));
    WriteLe16(msg_type, dst + offsetof(StreamMsgHeader, msg_type));
    WriteLe32(body_len, dst + offsetof(StreamMsgHeader, body_len));
    WriteLe64(hdr->sequence, dst + offsetof(StreamMsgHeader, sequence));
    WriteLe64((uint64_t)hdr->send_time_ns, dst + offsetof(StreamMsgHeader, send_time_ns));
}

int StreamQuoteSetKey(StreamQuote *quote, const char *key)
{
    size_t len;
    size_t ii;

    if (quote == NULL || key == NULL)
    {
        return -EINVAL;
    }

    len = strlen(key);
    if (len > STREAM_KEY_LEN)
    {
        return -EINVAL;
    }
    for (ii = 0; ii < len; ii++)
    {
        if ((unsigned char)key[ii] > 0x7F)
        {
            return -EINVAL;     /* 키는 ASCII 만 — TS 쪽 디코딩 규칙과 맞춘다 */
        }
    }

    memset(quote->key, 0, sizeof(quote->key));
    memcpy(quote->key, key, len);
    return 0;
}

ssize_t StreamMsgEncodeQuote(const StreamMsgHeader *hdr, const StreamQuote *quote,
                             uint8_t *out, size_t out_cap)
{
    uint8_t *body;

    if (hdr == NULL || quote == NULL || out == NULL)
    {
        return -EINVAL;
    }
    if (out_cap < STREAM_HEADER_SIZE + STREAM_QUOTE_SIZE)
    {
        return -ENOSPC;
    }

    WriteHeader(hdr, STREAM_MSG_TYPE_QUOTE, STREAM_QUOTE_SIZE, out);

    /*-------------------------------------------------------------------------
    본문 — 예약 영역까지 0으로 먼저 채워 초기화되지 않은 메모리가 새지 않게 한다
    -------------------------------------------------------------------------*/
    body = out + STREAM_HEADER_SIZE;
    memset(body, 0, STREAM_QUOTE_SIZE);
    memcpy(body + offsetof(StreamQuote, key), quote->key, STREAM_KEY_LEN);
    WriteLe64((uint64_t)quote->price, body + offsetof(StreamQuote, price));
    WriteLe64((uint64_t)quote->qty, body + offsetof(StreamQuote, qty));
    WriteLe32(quote->flags, body + offsetof(StreamQuote, flags));

    return (ssize_t)(STREAM_HEADER_SIZE + STREAM_QUOTE_SIZE);
}

ssize_t StreamMsgEncodeHeartbeat(const StreamMsgHeader *hdr, uint8_t *out, size_t out_cap)
{
    if (hdr == NULL || out == NULL)
    {
        return -EINVAL;
    }
    if (out_cap < STREAM_HEADER_SIZE)
    {
        return -ENOSPC;
    }

    WriteHeader(hdr, STREAM_MSG_TYPE_HEARTBEAT, 0, out);
    return (ssize_t)STREAM_HEADER_SIZE;
}

int StreamMsgDecodeHeader(const uint8_t *src, size_t len, StreamMsgHeader *out_hdr)
{
    StreamMsgHeader hdr;

    if (src == NULL || out_hdr == NULL)
    {
        return -EINVAL;
    }
    if (len < STREAM_HEADER_SIZE)
    {
        return -EMSGSIZE;
    }

    hdr.version      = ReadLe16(src + offsetof(StreamMsgHeader, version));
    hdr.msg_type     = ReadLe16(src + offsetof(StreamMsgHeader, msg_type));
    hdr.body_len     = ReadLe32(src + offsetof(StreamMsgHeader, body_len));
    hdr.sequence     = ReadLe64(src + offsetof(StreamMsgHeader, sequence));
    hdr.send_time_ns = U64ToI64(ReadLe64(src + offsetof(StreamMsgHeader, send_time_ns)));

    if (hdr.version != STREAM_MSG_VERSION)
    {
        return -EPROTO;         /* 깨지는 변경 이후의 메시지 — 연결을 끊고 재동기화한다 */
    }
    if (hdr.body_len > STREAM_MSG_MAX_BODY)
    {
        return -EOVERFLOW;
    }

    *out_hdr = hdr;
    return 0;
}

int StreamMsgDecodeQuote(const uint8_t *body, size_t body_len, StreamQuote *out_quote)
{
    StreamQuote quote;
    size_t      ii;
    int         seen_nul = 0;

    if (body == NULL || out_quote == NULL)
    {
        return -EINVAL;
    }
    if (body_len < STREAM_QUOTE_SIZE)
    {
        return -EMSGSIZE;
    }

    /*-------------------------------------------------------------------------
    키 검증 — 첫 NUL 뒤는 모두 NUL 이어야 한다. 쓰레기 바이트는 송신 측 초기화 누락이다.
    -------------------------------------------------------------------------*/
    for (ii = 0; ii < STREAM_KEY_LEN; ii++)
    {
        uint8_t byte = body[offsetof(StreamQuote, key) + ii];

        if (byte == 0)
        {
            seen_nul = 1;
        }
        else if (seen_nul || byte > 0x7F)
        {
            return -EBADMSG;
        }
    }

    memset(&quote, 0, sizeof(quote));
    memcpy(quote.key, body + offsetof(StreamQuote, key), STREAM_KEY_LEN);
    quote.price = U64ToI64(ReadLe64(body + offsetof(StreamQuote, price)));
    quote.qty   = U64ToI64(ReadLe64(body + offsetof(StreamQuote, qty)));
    quote.flags = ReadLe32(body + offsetof(StreamQuote, flags));
    /* reserved 와 STREAM_QUOTE_SIZE 뒤의 바이트는 v1 이 모르는 추가 필드다 — 읽지 않는다 */

    *out_quote = quote;
    return 0;
}
