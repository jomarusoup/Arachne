/*#############################################################################
FILE NAME   : stream_msg.h
DESCRIPTION : 스트림 채널 바이너리 계약의 정본 — 메시지 헤더·시세형 본문 구조체와 인코드·디코드 API
#############################################################################*/

#ifndef STREAM_MSG_H
#define STREAM_MSG_H

#include <stddef.h>
#include <stdint.h>

#include <sys/types.h>

/*-----------------------------------------------------------------------------
채널 계약 (정본은 이 헤더다 — 문서·TS 디코더·매니페스트는 여기서 파생한다)
- 바이트 순서: 모든 다중 바이트 필드는 리틀엔디언이다. 이 채널에서 이 규칙은 여기에만 적는다.
- 메시지 = [헤더 24바이트][본문 body_len 바이트]. 헤더의 body_len 이 경계를 정하므로
  TCP 위에서 별도 길이 prefix 없이 스스로 프레이밍된다.
- 진화는 추가만 허용한다: 새 메시지 종류, 본문 끝에 필드 덧붙이기, 예약 영역 사용(0 = 없음).
  수신 측은 아는 크기만 읽고 남는 본문 바이트는 건너뛴다.
- 필드 의미·크기·순서가 바뀌는 변경은 깨지는 변경이다. STREAM_MSG_VERSION 을 올린다.
-----------------------------------------------------------------------------*/
#define STREAM_MSG_VERSION     1u
#define STREAM_MSG_MAX_BODY    4096u        /* 본문 최대 길이 — 수신 측 DoS 상한 */
#define STREAM_KEY_LEN         16u          /* 키 고정 길이 — ASCII, 남는 바이트는 NUL */

/* 가격·수량은 스케일 정수다. 부동소수점으로 바꾸지 않는다 */
#define STREAM_PRICE_SCALE     10000        /* 가격 소수 4자리: 1234500 = 123.4500 */
#define STREAM_QTY_SCALE       1000         /* 수량 소수 3자리: 10000 = 10.000 */

/* 메시지 종류 — 값은 한 번 정하면 재사용하지 않는다 */
#define STREAM_MSG_TYPE_HEARTBEAT  0u       /* 본문 없음 */
#define STREAM_MSG_TYPE_QUOTE      1u       /* 본문 = StreamQuote */

/*-----------------------------------------------------------------------------
메시지 헤더 — 24바이트, 암묵 패딩 없음
-----------------------------------------------------------------------------*/
typedef struct StreamMsgHeader
{
    uint16_t version;          /*  0 계약 버전 — STREAM_MSG_VERSION 과 다르면 거부 */
    uint16_t msg_type;         /*  2 STREAM_MSG_TYPE_* */
    uint32_t body_len;         /*  4 헤더 뒤 본문 바이트 수 */
    uint64_t sequence;         /*  8 채널 단조 증가 시퀀스 — 갭 감지 기준 */
    int64_t  send_time_ns;     /* 16 송신 시각, Unix epoch(UTC) 기준 나노초 */
} StreamMsgHeader;

/*-----------------------------------------------------------------------------
시세형 본문 — 48바이트. 키를 앞에 두고 8바이트 필드를 8의 배수 위치에 둔다.
reserved 는 송신 측이 0으로 채우고 수신 측은 v1 에서 무시한다.
-----------------------------------------------------------------------------*/
typedef struct StreamQuote
{
    char     key[STREAM_KEY_LEN];  /*  0 NUL 패딩 고정 길이, 16자를 꽉 채우면 종료 NUL 없음 */
    int64_t  price;                /* 16 가격 × STREAM_PRICE_SCALE */
    int64_t  qty;                  /* 24 수량 × STREAM_QTY_SCALE */
    uint32_t flags;                /* 32 비트 플래그 — 모르는 비트는 무시 */
    uint8_t  reserved[12];         /* 36 추가 진화용 예약 영역 */
} StreamQuote;

#define STREAM_HEADER_SIZE  24u
#define STREAM_QUOTE_SIZE   48u

/*-----------------------------------------------------------------------------
레이아웃 고정 — 이 값이 바뀌면 컴파일이 멈춘다. 의도한 변경이면 계약 변경 절차를 밟는다.
-----------------------------------------------------------------------------*/
_Static_assert(sizeof(StreamMsgHeader) == STREAM_HEADER_SIZE, "StreamMsgHeader 크기");
_Static_assert(offsetof(StreamMsgHeader, version)      == 0,  "version 오프셋");
_Static_assert(offsetof(StreamMsgHeader, msg_type)     == 2,  "msg_type 오프셋");
_Static_assert(offsetof(StreamMsgHeader, body_len)     == 4,  "body_len 오프셋");
_Static_assert(offsetof(StreamMsgHeader, sequence)     == 8,  "sequence 오프셋");
_Static_assert(offsetof(StreamMsgHeader, send_time_ns) == 16, "send_time_ns 오프셋");

_Static_assert(sizeof(StreamQuote) == STREAM_QUOTE_SIZE, "StreamQuote 크기");
_Static_assert(offsetof(StreamQuote, key)      == 0,  "key 오프셋");
_Static_assert(offsetof(StreamQuote, price)    == 16, "price 오프셋");
_Static_assert(offsetof(StreamQuote, qty)      == 24, "qty 오프셋");
_Static_assert(offsetof(StreamQuote, flags)    == 32, "flags 오프셋");
_Static_assert(offsetof(StreamQuote, reserved) == 36, "reserved 오프셋");

/*-----------------------------------------------------------------------------
API — 실패는 음수 errno 로 돌려준다
- StreamQuoteSetKey      : 키를 NUL 패딩해 채운다. 16자 초과·비 ASCII 는 -EINVAL
- StreamMsgEncodeQuote   : 헤더 + 본문을 out 에 쓰고 쓴 바이트 수를 돌려준다. hdr 에서는
    sequence·send_time_ns 만 쓰고 version·msg_type·body_len 은 함수가 채운다. 버퍼 부족은 -ENOSPC
- StreamMsgEncodeHeartbeat : 본문 없는 하트비트를 쓴다
- StreamMsgDecodeHeader  : 헤더를 해석하고 버전·본문 상한을 검사한다
    -EMSGSIZE 입력이 헤더보다 짧다 / -EPROTO 버전 불일치 / -EOVERFLOW body_len 상한 초과
- StreamMsgDecodeQuote   : 본문을 해석한다. 본문이 짧으면 -EMSGSIZE, 키 패딩 오염이면 -EBADMSG.
    본문이 STREAM_QUOTE_SIZE 보다 길면 뒤쪽은 새 버전 필드로 보고 무시한다
-----------------------------------------------------------------------------*/
int     StreamQuoteSetKey(StreamQuote *quote, const char *key);
ssize_t StreamMsgEncodeQuote(const StreamMsgHeader *hdr, const StreamQuote *quote,
                             uint8_t *out, size_t out_cap);
ssize_t StreamMsgEncodeHeartbeat(const StreamMsgHeader *hdr, uint8_t *out, size_t out_cap);
int     StreamMsgDecodeHeader(const uint8_t *src, size_t len, StreamMsgHeader *out_hdr);
int     StreamMsgDecodeQuote(const uint8_t *body, size_t body_len, StreamQuote *out_quote);

#endif /* STREAM_MSG_H */
