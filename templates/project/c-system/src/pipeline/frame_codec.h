/*#############################################################################
FILE NAME   : frame_codec.h
DESCRIPTION : 길이 prefix 프레이밍 인코더·디코더 공개 인터페이스 (부분 수신 재조립, 최대 프레임 상한)
#############################################################################*/

#ifndef FRAME_CODEC_H
#define FRAME_CODEC_H

#include <stddef.h>
#include <stdint.h>

#include <sys/types.h>

/*-----------------------------------------------------------------------------
와이어 형식
[4바이트 payload 길이, 빅엔디언][payload]
길이 필드의 엔디언과 최대 크기는 채널 계약(api-contracts)이 정본이다.
이 예제는 네트워크 바이트 순서(빅엔디언)를 쓴다. 길이 0 프레임은 하트비트로 허용한다.
-----------------------------------------------------------------------------*/
#define FRAME_HEADER_SIZE 4u

typedef struct FrameDecoder FrameDecoder;

/*-----------------------------------------------------------------------------
완성된 프레임마다 호출된다. payload는 호출 동안만 유효하다(보관하려면 복사).
0을 돌려주면 계속한다. 음수 errno를 돌려주면 디코딩을 멈추고 FrameDecoderFeed가 그 값을
돌려준다. 이때 디코더는 오류 상태가 되므로 호출자는 연결을 끊는다.
-----------------------------------------------------------------------------*/
typedef int (*FrameHandler)(const uint8_t *payload, size_t len, void *ctx);

int     FrameDecoderCreate(size_t max_frame, FrameDecoder **out_dec);
void    FrameDecoderDestroy(FrameDecoder *dec);
int     FrameDecoderFeed(FrameDecoder *dec, const uint8_t *data, size_t len,
                         FrameHandler on_frame, void *ctx);
ssize_t FrameEncode(const void *payload, size_t len, uint8_t *out, size_t out_cap);

#endif /* FRAME_CODEC_H */
