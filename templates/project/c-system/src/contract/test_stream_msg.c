/*#############################################################################
FILE NAME   : test_stream_msg.c
DESCRIPTION : 스트림 메시지 계약 테스트 — 알려진 바이트 열 해석, 왕복, 경계값, 거부 경로, 커밋된 벡터 해석
#############################################################################*/

#include <errno.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "stream_msg.h"

#define MSG_CAP  (STREAM_HEADER_SIZE + STREAM_QUOTE_SIZE + 16u)

static int g_FailCount = 0;

static void Check(int cond, const char *what, int line)
{
    if (!cond)
    {
        fprintf(stderr, "[FAIL] line %d: %s\n", line, what);
        g_FailCount++;
    }
}

/*-----------------------------------------------------------------------------
테스트: 손으로 적은 리틀엔디언 바이트 열을 해석한다. 호스트 바이트 순서와 무관해야 한다.
-----------------------------------------------------------------------------*/
static void TestDecodeKnownBytes(void)
{
    static const uint8_t bytes[STREAM_HEADER_SIZE] = {
        0x01, 0x00,                                         /* version 1 */
        0x01, 0x00,                                         /* msg_type QUOTE */
        0x30, 0x00, 0x00, 0x00,                             /* body_len 48 */
        0x08, 0x07, 0x06, 0x05, 0x04, 0x03, 0x02, 0x01,     /* sequence */
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,     /* send_time_ns -1 */
    };
    StreamMsgHeader hdr;

    Check(StreamMsgDecodeHeader(bytes, sizeof(bytes), &hdr) == 0, "헤더 해석 성공", __LINE__);
    Check(hdr.version == 1 && hdr.msg_type == STREAM_MSG_TYPE_QUOTE, "버전·종류", __LINE__);
    Check(hdr.body_len == STREAM_QUOTE_SIZE, "본문 길이", __LINE__);
    Check(hdr.sequence == UINT64_C(0x0102030405060708), "시퀀스 리틀엔디언", __LINE__);
    Check(hdr.send_time_ns == -1, "음수 시각 2의 보수", __LINE__);
}

/*-----------------------------------------------------------------------------
테스트: 경계값 왕복 — 2^53 초과·INT64_MIN·INT64_MAX·16자 키
-----------------------------------------------------------------------------*/
static void TestRoundTripExtremes(void)
{
    uint8_t         buf[MSG_CAP];
    StreamMsgHeader hdr;
    StreamMsgHeader got_hdr;
    StreamQuote     quote;
    StreamQuote     got;
    ssize_t         len;

    memset(&hdr, 0, sizeof(hdr));
    memset(&quote, 0, sizeof(quote));
    hdr.sequence     = UINT64_MAX;
    hdr.send_time_ns = INT64_C(9007199254740993);
    Check(StreamQuoteSetKey(&quote, "ABCDEFGHIJKLMNOP") == 0, "16자 키 허용", __LINE__);
    quote.price = INT64_MIN;
    quote.qty   = INT64_MAX;
    quote.flags = 0xFFFFFFFFu;

    len = StreamMsgEncodeQuote(&hdr, &quote, buf, sizeof(buf));
    Check(len == (ssize_t)(STREAM_HEADER_SIZE + STREAM_QUOTE_SIZE), "인코딩 길이", __LINE__);
    Check(StreamMsgDecodeHeader(buf, (size_t)len, &got_hdr) == 0, "헤더 해석", __LINE__);
    Check(got_hdr.sequence == UINT64_MAX, "최대 시퀀스", __LINE__);
    Check(got_hdr.send_time_ns == INT64_C(9007199254740993), "2^53+1 시각", __LINE__);
    Check(StreamMsgDecodeQuote(buf + STREAM_HEADER_SIZE, got_hdr.body_len, &got) == 0,
          "본문 해석", __LINE__);
    Check(memcmp(got.key, "ABCDEFGHIJKLMNOP", STREAM_KEY_LEN) == 0, "키 왕복", __LINE__);
    Check(got.price == INT64_MIN && got.qty == INT64_MAX, "INT64 경계 왕복", __LINE__);
    Check(got.flags == 0xFFFFFFFFu, "플래그 왕복", __LINE__);
}

/*-----------------------------------------------------------------------------
테스트: 예약 영역과 키 패딩은 0으로 나간다 — 송신 측 메모리 쓰레기가 새지 않는다
-----------------------------------------------------------------------------*/
static void TestEncodeZeroesPadding(void)
{
    uint8_t         buf[MSG_CAP];
    StreamMsgHeader hdr;
    StreamQuote     quote;
    size_t          ii;
    int             all_zero = 1;

    memset(&hdr, 0, sizeof(hdr));
    memset(&quote, 0xCC, sizeof(quote));
    Check(StreamQuoteSetKey(&quote, "AB") == 0, "짧은 키", __LINE__);
    Check(StreamMsgEncodeQuote(&hdr, &quote, buf, sizeof(buf)) > 0, "인코딩", __LINE__);

    for (ii = 2; ii < STREAM_KEY_LEN; ii++)
    {
        all_zero &= (buf[STREAM_HEADER_SIZE + ii] == 0);
    }
    for (ii = 0; ii < sizeof(quote.reserved); ii++)
    {
        all_zero &= (buf[STREAM_HEADER_SIZE + offsetof(StreamQuote, reserved) + ii] == 0);
    }
    Check(all_zero, "키 패딩·예약 영역 0", __LINE__);
}

/*-----------------------------------------------------------------------------
테스트: 거부 경로 — 짧은 입력, 버전 불일치, 상한 초과, 키 오염, 버퍼 부족
-----------------------------------------------------------------------------*/
static void TestRejects(void)
{
    uint8_t         buf[MSG_CAP];
    StreamMsgHeader hdr;
    StreamQuote     quote;
    ssize_t         len;

    memset(&hdr, 0, sizeof(hdr));
    memset(&quote, 0, sizeof(quote));
    Check(StreamQuoteSetKey(&quote, "ABCDEFGHIJKLMNOPQ") == -EINVAL, "17자 키 거부", __LINE__);
    Check(StreamQuoteSetKey(&quote, "\xC3\xA9") == -EINVAL, "비 ASCII 키 거부", __LINE__);
    Check(StreamQuoteSetKey(&quote, "KEY") == 0, "정상 키", __LINE__);

    Check(StreamMsgEncodeQuote(NULL, &quote, buf, sizeof(buf)) == -EINVAL, "NULL 헤더", __LINE__);
    Check(StreamMsgEncodeQuote(&hdr, NULL, buf, sizeof(buf)) == -EINVAL, "NULL 본문", __LINE__);
    Check(StreamMsgEncodeHeartbeat(&hdr, NULL, sizeof(buf)) == -EINVAL, "NULL 출력", __LINE__);
    Check(StreamMsgEncodeHeartbeat(&hdr, buf, STREAM_HEADER_SIZE - 1) == -ENOSPC,
          "하트비트 버퍼 부족", __LINE__);
    Check(StreamMsgDecodeHeader(NULL, sizeof(buf), &hdr) == -EINVAL, "NULL 입력", __LINE__);
    Check(StreamMsgDecodeQuote(buf, STREAM_QUOTE_SIZE, NULL) == -EINVAL, "NULL 결과", __LINE__);
    Check(StreamQuoteSetKey(NULL, "KEY") == -EINVAL, "NULL 구조체", __LINE__);

    Check(StreamMsgEncodeQuote(&hdr, &quote, buf, STREAM_HEADER_SIZE) == -ENOSPC,
          "버퍼 부족", __LINE__);
    len = StreamMsgEncodeQuote(&hdr, &quote, buf, sizeof(buf));
    Check(len > 0, "인코딩", __LINE__);

    Check(StreamMsgDecodeHeader(buf, STREAM_HEADER_SIZE - 1, &hdr) == -EMSGSIZE,
          "짧은 헤더", __LINE__);
    Check(StreamMsgDecodeQuote(buf + STREAM_HEADER_SIZE, STREAM_QUOTE_SIZE - 1, &quote) == -EMSGSIZE,
          "짧은 본문", __LINE__);

    buf[0] = 2;                                         /* 미래 버전 */
    Check(StreamMsgDecodeHeader(buf, (size_t)len, &hdr) == -EPROTO, "버전 불일치", __LINE__);
    buf[0] = 1;

    buf[offsetof(StreamMsgHeader, body_len) + 2] = 0x01;    /* body_len = 65536 + 48 */
    Check(StreamMsgDecodeHeader(buf, (size_t)len, &hdr) == -EOVERFLOW, "본문 상한 초과", __LINE__);
    buf[offsetof(StreamMsgHeader, body_len) + 2] = 0x00;

    buf[STREAM_HEADER_SIZE + 5] = 'X';                  /* "KEY\0\0X..." — NUL 뒤 쓰레기 */
    Check(StreamMsgDecodeQuote(buf + STREAM_HEADER_SIZE, STREAM_QUOTE_SIZE, &quote) == -EBADMSG,
          "키 패딩 오염", __LINE__);
}

/*-----------------------------------------------------------------------------
테스트: 커밋된 벡터 해석 — 디코더를 바꿔도 이미 나간 메시지를 읽을 수 있어야 한다
-----------------------------------------------------------------------------*/
static size_t ReadVector(const char *path, uint8_t *out, size_t cap)
{
    FILE  *fp = fopen(path, "rb");
    size_t got;

    if (fp == NULL)
    {
        fprintf(stderr, "[FAIL] 벡터 열기 실패: %s\n", path);
        g_FailCount++;
        return 0;
    }
    got = fread(out, 1, cap, fp);
    fclose(fp);
    return got;
}

static void TestCommittedVectors(void)
{
    uint8_t         buf[MSG_CAP];
    StreamMsgHeader hdr;
    StreamQuote     quote;
    size_t          len;

    len = ReadVector("vectors/quote_extended.bin", buf, sizeof(buf));
    Check(len == STREAM_HEADER_SIZE + STREAM_QUOTE_SIZE + 8, "확장 벡터 길이", __LINE__);
    Check(StreamMsgDecodeHeader(buf, len, &hdr) == 0, "확장 벡터 헤더", __LINE__);
    Check(hdr.body_len == STREAM_QUOTE_SIZE + 8, "확장 본문 길이", __LINE__);
    Check(StreamMsgDecodeQuote(buf + STREAM_HEADER_SIZE, hdr.body_len, &quote) == 0,
          "모르는 꼬리 필드 무시", __LINE__);
    Check(quote.price == -250000 && quote.qty == 1, "확장 벡터 값", __LINE__);

    len = ReadVector("vectors/heartbeat.bin", buf, sizeof(buf));
    Check(len == STREAM_HEADER_SIZE, "하트비트 길이", __LINE__);
    Check(StreamMsgDecodeHeader(buf, len, &hdr) == 0, "하트비트 헤더", __LINE__);
    Check(hdr.msg_type == STREAM_MSG_TYPE_HEARTBEAT && hdr.body_len == 0, "하트비트 값", __LINE__);
}

int main(void)
{
    TestDecodeKnownBytes();
    TestRoundTripExtremes();
    TestEncodeZeroesPadding();
    TestRejects();
    TestCommittedVectors();

    if (g_FailCount != 0)
    {
        fprintf(stderr, "test_stream_msg: %d건 실패\n", g_FailCount);
        return EXIT_FAILURE;
    }
    printf("test_stream_msg: 통과\n");
    return EXIT_SUCCESS;
}
