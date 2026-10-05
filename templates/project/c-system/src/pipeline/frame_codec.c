/*#############################################################################
FILE NAME   : frame_codec.c
DESCRIPTION : 길이 prefix 프레이밍 구현 — 부분 수신 재조립, 최대 프레임 상한, 완성 프레임 무복사 전달
#############################################################################*/

#include <errno.h>
#include <limits.h>
#include <stdlib.h>
#include <string.h>

#include "frame_codec.h"

/*-----------------------------------------------------------------------------
디코더 상태
헤더를 모으는 중(in_body == 0)이거나 본문을 모으는 중(in_body == 1)이다.
본문 버퍼는 생성 시 max_frame 크기로 한 번만 할당한다. 수신 경로에서는 할당하지 않는다.
-----------------------------------------------------------------------------*/
struct FrameDecoder
{
    size_t   max_frame;                    /* 허용 최대 payload 길이 — DoS 상한 */
    uint8_t  header[FRAME_HEADER_SIZE];    /* 부분 수신된 길이 필드 */
    size_t   header_got;
    size_t   body_len;                     /* 헤더에서 읽은 payload 길이 */
    size_t   body_got;
    int      in_body;
    int      failed;                       /* 오류 후에는 더 이상 해석하지 않는다 */
    uint8_t *body;                         /* 부분 수신 재조립 버퍼 */
};

/*-----------------------------------------------------------------------------
빅엔디언 32비트 변환. 정렬되지 않은 주소에서도 안전하도록 바이트 단위로 처리한다.
-----------------------------------------------------------------------------*/
static uint32_t ReadBe32(const uint8_t *src)
{
    return ((uint32_t)src[0] << 24) | ((uint32_t)src[1] << 16)
         | ((uint32_t)src[2] << 8)  |  (uint32_t)src[3];
}

static void WriteBe32(uint32_t value, uint8_t *dst)
{
    dst[0] = (uint8_t)(value >> 24);
    dst[1] = (uint8_t)(value >> 16);
    dst[2] = (uint8_t)(value >> 8);
    dst[3] = (uint8_t)value;
}

static size_t MinSize(size_t lhs, size_t rhs)
{
    return lhs < rhs ? lhs : rhs;
}

/*-----------------------------------------------------------------------------
다음 프레임을 받을 상태로 되돌린다.
-----------------------------------------------------------------------------*/
static void ResetFrame(FrameDecoder *dec)
{
    dec->header_got = 0;
    dec->body_len   = 0;
    dec->body_got   = 0;
    dec->in_body    = 0;
}

/*-----------------------------------------------------------------------------
완성 프레임을 처리기에 넘긴다. 처리기가 음수를 돌려주면 디코더를 오류 상태로 둔다.
-----------------------------------------------------------------------------*/
static int Deliver(FrameDecoder *dec, const uint8_t *payload, FrameHandler on_frame, void *ctx)
{
    int rc = on_frame(payload, dec->body_len, ctx);

    ResetFrame(dec);
    if (rc < 0)
    {
        dec->failed = 1;
    }
    return rc;
}

/*=============================================================================
FUNCTION    : FrameDecoderCreate
DESCRIPTION : 디코더를 만든다. 해제 책임은 호출자에게 있다(FrameDecoderDestroy).
PARAMETERS  : size_t         max_frame - 허용 최대 payload 길이 (1 ~ UINT32_MAX)
              FrameDecoder **out_dec   - 생성된 핸들을 받을 위치
RETURNED    : 0 성공, -EINVAL 잘못된 인자, -ENOMEM 할당 실패
=============================================================================*/
int FrameDecoderCreate(size_t max_frame, FrameDecoder **out_dec)
{
    FrameDecoder *dec = NULL;

    if (out_dec == NULL || max_frame == 0 || max_frame > UINT32_MAX)
    {
        return -EINVAL;
    }

    dec = calloc(1, sizeof(*dec));
    if (dec == NULL)
    {
        return -ENOMEM;
    }
    dec->body = malloc(max_frame);
    if (dec->body == NULL)
    {
        free(dec);
        return -ENOMEM;
    }
    dec->max_frame = max_frame;
    ResetFrame(dec);

    *out_dec = dec;
    return 0;
}

/*=============================================================================
FUNCTION    : FrameDecoderDestroy
DESCRIPTION : 디코더를 해제한다.
PARAMETERS  : FrameDecoder *dec - 해제할 핸들 (NULL 허용)
=============================================================================*/
void FrameDecoderDestroy(FrameDecoder *dec)
{
    if (dec == NULL)
    {
        return;
    }
    free(dec->body);
    dec->body = NULL;
    free(dec);
}

/*-----------------------------------------------------------------------------
길이 필드를 모은다. 4바이트가 다 모이면 상한을 검사하고 본문 단계로 넘어간다.
상한 검사는 본문이 도착하기 전에 한다. 거짓 길이로 메모리를 소모시키는 공격을 막는다.
반환: 소비한 바이트 수, 상한 초과면 -EMSGSIZE
-----------------------------------------------------------------------------*/
static long ConsumeHeader(FrameDecoder *dec, const uint8_t *data, size_t len)
{
    size_t take = MinSize(FRAME_HEADER_SIZE - dec->header_got, len);

    memcpy(dec->header + dec->header_got, data, take);
    dec->header_got += take;
    if (dec->header_got < FRAME_HEADER_SIZE)
    {
        return (long)take;
    }

    dec->body_len = ReadBe32(dec->header);
    if (dec->body_len > dec->max_frame)
    {
        dec->failed = 1;
        return -EMSGSIZE;
    }
    dec->in_body  = 1;
    dec->body_got = 0;
    return (long)take;
}

/*=============================================================================
FUNCTION    : FrameDecoderFeed
DESCRIPTION : 수신한 바이트를 넣고, 완성된 프레임마다 on_frame을 부른다.
              recv가 돌려준 조각을 크기와 무관하게 그대로 넣으면 된다.
              본문 전체가 입력 안에 있으면 복사 없이 입력 포인터를 그대로 넘긴다.
PARAMETERS  : FrameDecoder  *dec      - 디코더
              const uint8_t *data     - 수신 바이트
              size_t         len      - 수신 바이트 수
              FrameHandler   on_frame - 프레임 처리기
              void          *ctx      - 처리기 문맥
RETURNED    : 0 성공, -EMSGSIZE 상한 초과 프레임, -EPROTO 이미 오류 상태,
              -EINVAL 잘못된 인자, 처리기가 돌려준 음수 errno
=============================================================================*/
int FrameDecoderFeed(FrameDecoder *dec, const uint8_t *data, size_t len,
                     FrameHandler on_frame, void *ctx)
{
    /* HOTPATH */
    size_t pos = 0;
    long   took = 0;
    int    rc   = 0;

    if (dec == NULL || on_frame == NULL || (data == NULL && len != 0))
    {
        return -EINVAL;
    }
    if (dec->failed)
    {
        return -EPROTO;
    }

    while (pos < len)
    {
        if (!dec->in_body)
        {
            took = ConsumeHeader(dec, data + pos, len - pos);
            if (took < 0)
            {
                return (int)took;
            }
            pos += (size_t)took;
            if (!dec->in_body)
            {
                break;   /* 헤더가 아직 덜 왔다 */
            }
        }

        /* 무복사 경로: 본문 전체가 이번 입력 안에 있다 */
        if (dec->body_got == 0 && len - pos >= dec->body_len)
        {
            const uint8_t *payload = data + pos;

            pos += dec->body_len;
            rc = Deliver(dec, payload, on_frame, ctx);
            if (rc < 0)
            {
                return rc;
            }
            continue;
        }

        /* 재조립 경로: 본문 일부만 왔다 */
        took = (long)MinSize(dec->body_len - dec->body_got, len - pos);
        memcpy(dec->body + dec->body_got, data + pos, (size_t)took);
        dec->body_got += (size_t)took;
        pos           += (size_t)took;
        if (dec->body_got == dec->body_len)
        {
            rc = Deliver(dec, dec->body, on_frame, ctx);
            if (rc < 0)
            {
                return rc;
            }
        }
    }
    return 0;
}

/*=============================================================================
FUNCTION    : FrameEncode
DESCRIPTION : 길이 필드와 payload를 out에 쓴다. 송신 큐에 넣기 전에 한 번 부른다.
PARAMETERS  : const void *payload - 본문 (len이 0이면 NULL 허용)
              size_t      len     - 본문 길이
              uint8_t    *out     - 출력 버퍼
              size_t      out_cap - 출력 버퍼 크기
RETURNED    : 쓴 바이트 수, -EMSGSIZE 길이 필드 범위 초과, -ENOSPC 출력 버퍼 부족,
              -EINVAL 잘못된 인자
=============================================================================*/
ssize_t FrameEncode(const void *payload, size_t len, uint8_t *out, size_t out_cap)
{
    if (out == NULL || (payload == NULL && len != 0))
    {
        return -EINVAL;
    }
    if (len > UINT32_MAX || len > (size_t)SSIZE_MAX - FRAME_HEADER_SIZE)
    {
        return -EMSGSIZE;
    }
    if (out_cap < FRAME_HEADER_SIZE + len)
    {
        return -ENOSPC;
    }

    WriteBe32((uint32_t)len, out);
    if (len != 0)
    {
        memcpy(out + FRAME_HEADER_SIZE, payload, len);
    }
    return (ssize_t)(FRAME_HEADER_SIZE + len);
}
