/*#############################################################################
FILE NAME   : test_frame_codec.c
DESCRIPTION : 프레임 코덱 테스트 — 1바이트씩·임의 조각·한 번에 넣기, 상한 초과, 처리기 중단, 인코딩 경계
#############################################################################*/

#include <errno.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "frame_codec.h"

#define TEST_MAX_FRAME   64u     /* 테스트용 최대 payload */
#define MAX_COLLECTED    16u     /* 수집할 최대 프레임 수 */
#define STREAM_CAP       512u    /* 인코딩한 스트림 버퍼 크기 */

static int g_FailCount = 0;

/*-----------------------------------------------------------------------------
수신한 프레임을 복사해 모은다. payload는 호출 동안만 유효하므로 복사가 필요하다.
-----------------------------------------------------------------------------*/
typedef struct
{
    size_t  count;
    size_t  lens[MAX_COLLECTED];
    uint8_t data[MAX_COLLECTED][TEST_MAX_FRAME];
} Collector;

static void Check(int cond, const char *what, int line)
{
    if (!cond)
    {
        fprintf(stderr, "[FAIL] line %d: %s\n", line, what);
        g_FailCount++;
    }
}

static int CollectFrame(const uint8_t *payload, size_t len, void *ctx)
{
    Collector *col = ctx;

    if (col->count >= MAX_COLLECTED || len > TEST_MAX_FRAME)
    {
        return -ENOSPC;
    }
    if (len != 0)
    {
        memcpy(col->data[col->count], payload, len);
    }
    col->lens[col->count] = len;
    col->count++;
    return 0;
}

static int AbortOnFirst(const uint8_t *payload, size_t len, void *ctx)
{
    int *calls = ctx;

    (void)payload;
    (void)len;
    (*calls)++;
    return -ECANCELED;
}

/*-----------------------------------------------------------------------------
테스트 스트림: 길이 0(하트비트), 1, 5, 최대 길이 프레임을 이어 붙인다.
-----------------------------------------------------------------------------*/
static const char  g_Hello[]                 = "hello";
static uint8_t     g_MaxPayload[TEST_MAX_FRAME] = {0};

static size_t BuildStream(uint8_t *stream, size_t cap)
{
    size_t  used = 0;
    uint8_t one  = 0xA5;
    size_t  ii   = 0;

    for (ii = 0; ii < TEST_MAX_FRAME; ii++)
    {
        g_MaxPayload[ii] = (uint8_t)(ii * 7 + 1);
    }
    used += (size_t)FrameEncode(NULL, 0, stream + used, cap - used);
    used += (size_t)FrameEncode(&one, 1, stream + used, cap - used);
    used += (size_t)FrameEncode(g_Hello, 5, stream + used, cap - used);
    used += (size_t)FrameEncode(g_MaxPayload, TEST_MAX_FRAME, stream + used, cap - used);
    return used;
}

static void AssertStreamFrames(const Collector *col, int line)
{
    Check(col->count == 4, "프레임 4개 수신", line);
    if (col->count != 4)
    {
        return;
    }
    Check(col->lens[0] == 0, "하트비트 길이 0", line);
    Check(col->lens[1] == 1 && col->data[1][0] == 0xA5, "1바이트 프레임", line);
    Check(col->lens[2] == 5 && memcmp(col->data[2], g_Hello, 5) == 0, "hello 프레임", line);
    Check(col->lens[3] == TEST_MAX_FRAME
          && memcmp(col->data[3], g_MaxPayload, TEST_MAX_FRAME) == 0, "최대 길이 프레임", line);
}

/*-----------------------------------------------------------------------------
테스트: 같은 스트림을 조각 크기 1·3·7·전체로 넣어도 같은 프레임이 나온다
-----------------------------------------------------------------------------*/
static void TestReassemblyAnyChunkSize(void)
{
    static const size_t chunk_sizes[] = { 1, 3, 7, STREAM_CAP };
    uint8_t       stream[STREAM_CAP];
    size_t        stream_len = 0;
    size_t        ii         = 0;
    size_t        pos        = 0;
    size_t        chunk      = 0;
    FrameDecoder *dec        = NULL;
    Collector     col;

    stream_len = BuildStream(stream, sizeof(stream));
    Check(stream_len == 4 * FRAME_HEADER_SIZE + 0 + 1 + 5 + TEST_MAX_FRAME, "스트림 길이", __LINE__);

    for (ii = 0; ii < sizeof(chunk_sizes) / sizeof(chunk_sizes[0]); ii++)
    {
        /* Arrange */
        memset(&col, 0, sizeof(col));
        Check(FrameDecoderCreate(TEST_MAX_FRAME, &dec) == 0, "디코더 생성", __LINE__);
        if (dec == NULL)
        {
            return;
        }

        /* Act: recv가 조각을 돌려주는 상황을 흉내 낸다 */
        for (pos = 0; pos < stream_len; pos += chunk)
        {
            chunk = chunk_sizes[ii];
            if (chunk > stream_len - pos)
            {
                chunk = stream_len - pos;
            }
            Check(FrameDecoderFeed(dec, stream + pos, chunk, CollectFrame, &col) == 0,
                  "Feed 성공", __LINE__);
        }

        /* Assert */
        AssertStreamFrames(&col, __LINE__);
        FrameDecoderDestroy(dec);
        dec = NULL;
    }
}

/*-----------------------------------------------------------------------------
테스트: 상한 초과 길이는 본문이 오기 전에 거부되고, 이후 입력도 거부된다
-----------------------------------------------------------------------------*/
static void TestOversizedFrameRejected(void)
{
    uint8_t       header[FRAME_HEADER_SIZE] = { 0x00, 0x00, 0x00, TEST_MAX_FRAME + 1 };
    uint8_t       huge[FRAME_HEADER_SIZE]   = { 0xFF, 0xFF, 0xFF, 0xFF };
    FrameDecoder *dec  = NULL;
    Collector     col;
    size_t        ii   = 0;
    int           rc   = 0;

    /* Arrange */
    memset(&col, 0, sizeof(col));
    Check(FrameDecoderCreate(TEST_MAX_FRAME, &dec) == 0, "디코더 생성", __LINE__);
    if (dec == NULL)
    {
        return;
    }

    /* Act: 헤더만 1바이트씩 넣는다 — 본문 없이도 마지막 헤더 바이트에서 거부돼야 한다 */
    for (ii = 0; ii < FRAME_HEADER_SIZE; ii++)
    {
        rc = FrameDecoderFeed(dec, header + ii, 1, CollectFrame, &col);
        if (ii + 1 < FRAME_HEADER_SIZE)
        {
            Check(rc == 0, "헤더 일부는 대기", __LINE__);
        }
    }

    /* Assert */
    Check(rc == -EMSGSIZE, "상한+1 거부", __LINE__);
    Check(col.count == 0, "처리기 미호출", __LINE__);
    Check(FrameDecoderFeed(dec, header, 1, CollectFrame, &col) == -EPROTO, "오류 상태 유지", __LINE__);
    FrameDecoderDestroy(dec);

    /* 4GB 근처 길이도 할당 없이 거부한다 */
    Check(FrameDecoderCreate(TEST_MAX_FRAME, &dec) == 0, "디코더 재생성", __LINE__);
    if (dec == NULL)
    {
        return;
    }
    Check(FrameDecoderFeed(dec, huge, sizeof(huge), CollectFrame, &col) == -EMSGSIZE,
          "0xFFFFFFFF 거부", __LINE__);
    FrameDecoderDestroy(dec);
}

/*-----------------------------------------------------------------------------
테스트: 처리기가 음수를 돌려주면 즉시 멈추고 그 값을 돌려준다
-----------------------------------------------------------------------------*/
static void TestHandlerAbortStops(void)
{
    uint8_t       stream[STREAM_CAP];
    size_t        stream_len = BuildStream(stream, sizeof(stream));
    FrameDecoder *dec        = NULL;
    int           calls      = 0;

    Check(FrameDecoderCreate(TEST_MAX_FRAME, &dec) == 0, "디코더 생성", __LINE__);
    if (dec == NULL)
    {
        return;
    }
    Check(FrameDecoderFeed(dec, stream, stream_len, AbortOnFirst, &calls) == -ECANCELED,
          "처리기 오류 전파", __LINE__);
    Check(calls == 1, "첫 프레임에서 중단", __LINE__);
    FrameDecoderDestroy(dec);
}

/*-----------------------------------------------------------------------------
테스트: 인코딩·생성 인자 경계
-----------------------------------------------------------------------------*/
static void TestEncodeAndCreateBounds(void)
{
    uint8_t       out[FRAME_HEADER_SIZE + 5];
    FrameDecoder *dec = NULL;

    Check(FrameEncode(g_Hello, 5, out, sizeof(out)) == (ssize_t)sizeof(out), "정확한 크기", __LINE__);
    Check(out[0] == 0 && out[1] == 0 && out[2] == 0 && out[3] == 5, "빅엔디언 길이", __LINE__);
    Check(FrameEncode(g_Hello, 5, out, sizeof(out) - 1) == -ENOSPC, "버퍼 부족", __LINE__);
    Check(FrameEncode(NULL, 1, out, sizeof(out)) == -EINVAL, "NULL payload", __LINE__);
    Check(FrameDecoderCreate(0, &dec) == -EINVAL, "상한 0 거부", __LINE__);
    Check(FrameDecoderCreate(TEST_MAX_FRAME, NULL) == -EINVAL, "NULL 출력 거부", __LINE__);
}

int main(void)
{
    TestReassemblyAnyChunkSize();
    TestOversizedFrameRejected();
    TestHandlerAbortStops();
    TestEncodeAndCreateBounds();

    if (g_FailCount != 0)
    {
        fprintf(stderr, "test_frame_codec: %d건 실패\n", g_FailCount);
        return EXIT_FAILURE;
    }
    printf("test_frame_codec: 통과\n");
    return EXIT_SUCCESS;
}
