/*#############################################################################
FILE NAME   : poc_wire.h
DESCRIPTION : 처리량 PoC 송신·수신 공통 와이어 형식, 단조 시계, 지연 히스토그램 (헤더 전용)
#############################################################################*/

#ifndef POC_WIRE_H
#define POC_WIRE_H

#include <stdint.h>
#include <string.h>
#include <time.h>

/*-----------------------------------------------------------------------------
와이어 형식 — c-system/src/pipeline/frame_codec 과 같은 프레이밍
[4바이트 payload 길이, 빅엔디언][payload]

payload (메시지 크기 = payload 바이트 수, 최소 POC_MIN_PAYLOAD)
  0  u32 LE kind       1=DATA 2=HELLO 3=END
  4  u32 LE reserved   0
  8  u64 LE field_a    DATA: 시퀀스 번호(0부터) / HELLO: 송신 시작 시각(단조 ns) / END: 송신 총 건수
 16  u64 LE field_b    DATA: 예정 송신 시각(시작 기준 상대 ns) / 그 외 0
 24  ...   0 채움
-----------------------------------------------------------------------------*/
#define POC_FRAME_HEADER  4u
#define POC_MIN_PAYLOAD   24u
#define POC_MAX_PAYLOAD   65536u

#define POC_KIND_DATA     1u
#define POC_KIND_HELLO    2u
#define POC_KIND_END      3u

/*-----------------------------------------------------------------------------
단조 시계. Node의 process.hrtime.bigint()(libuv uv_hrtime)와 같은 시계를 고른다.
macOS: CLOCK_MONOTONIC_RAW(= mach_continuous_time, 잠자기 포함, ns 해상도). 실측(Node 26)에서
hrtime 과 일치했다. CLOCK_UPTIME_RAW 는 잠자기 시간만큼 어긋나고, CLOCK_MONOTONIC 은 µs 해상도다.
Linux: CLOCK_MONOTONIC (libuv 와 같음).
같은 호스트에서 두 시계가 같은지는 HELLO 프레임으로 수신 측이 확인한다. 어긋나면 지연은
측정하지 않고 처리량·갭만 보고한다(latencyMeasured=false).
-----------------------------------------------------------------------------*/
static inline uint64_t PocNowNs(void)
{
#if defined(__APPLE__)
    return clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW);
#else
    struct timespec now;

    clock_gettime(CLOCK_MONOTONIC, &now);
    return (uint64_t)now.tv_sec * 1000000000ull + (uint64_t)now.tv_nsec;
#endif
}

static inline void PocPutBe32(uint8_t *dst, uint32_t value)
{
    dst[0] = (uint8_t)(value >> 24);
    dst[1] = (uint8_t)(value >> 16);
    dst[2] = (uint8_t)(value >> 8);
    dst[3] = (uint8_t)value;
}

static inline uint32_t PocGetBe32(const uint8_t *src)
{
    return ((uint32_t)src[0] << 24) | ((uint32_t)src[1] << 16)
         | ((uint32_t)src[2] << 8)  |  (uint32_t)src[3];
}

static inline void PocPutLe32(uint8_t *dst, uint32_t value)
{
    int ii;

    for (ii = 0; ii < 4; ii++)
        dst[ii] = (uint8_t)(value >> (8 * ii));
}

static inline uint32_t PocGetLe32(const uint8_t *src)
{
    return (uint32_t)src[0] | ((uint32_t)src[1] << 8)
         | ((uint32_t)src[2] << 16) | ((uint32_t)src[3] << 24);
}

static inline void PocPutLe64(uint8_t *dst, uint64_t value)
{
    int ii;

    for (ii = 0; ii < 8; ii++)
        dst[ii] = (uint8_t)(value >> (8 * ii));
}

static inline uint64_t PocGetLe64(const uint8_t *src)
{
    return (uint64_t)PocGetLe32(src) | ((uint64_t)PocGetLe32(src + 4) << 32);
}

/*-----------------------------------------------------------------------------
프레임 하나를 out 에 쓴다. out 은 POC_FRAME_HEADER + payload_len 바이트 이상이어야 한다.
padding 은 호출자가 미리 0으로 채워 둔다(묶음 버퍼를 한 번만 memset).
-----------------------------------------------------------------------------*/
static inline void PocEncodeFrame(uint8_t *out, uint32_t payload_len, uint32_t kind,
                                  uint64_t field_a, uint64_t field_b)
{
    PocPutBe32(out, payload_len);
    PocPutLe32(out + 4, kind);
    PocPutLe32(out + 8, 0);
    PocPutLe64(out + 12, field_a);
    PocPutLe64(out + 20, field_b);
}

/*-----------------------------------------------------------------------------
지연 히스토그램 — µs 단위 로그-선형 버킷(유효 숫자 약 1.5%), 메시지별 할당 없음.
0~127µs 는 1µs 단위, 그 위는 2의 거듭제곱 구간마다 64칸.
receiver.mjs 의 HistIndex/HistValue 와 같은 식이다.
-----------------------------------------------------------------------------*/
#define POC_HIST_BUCKETS 1792

static inline int PocHistIndex(uint64_t micros)
{
    int      top_bit;
    int      shift;
    uint64_t mantissa;

    if (micros > 0xFFFFFFFFull)
        micros = 0xFFFFFFFFull;
    if (micros < 128)
        return (int)micros;
    top_bit  = 63 - __builtin_clzll(micros);
    shift    = top_bit - 6;
    mantissa = micros >> shift;
    return 64 * shift + (int)mantissa;
}

static inline uint64_t PocHistValue(int index)
{
    int shift;
    int mantissa;

    if (index < 128)
        return (uint64_t)index;
    shift    = index / 64 - 1;
    mantissa = index - 64 * shift;
    return (uint64_t)mantissa << shift;
}

/*-----------------------------------------------------------------------------
누적 분포에서 분위수(0~1)에 해당하는 버킷 하한 값을 µs 로 돌려준다.
-----------------------------------------------------------------------------*/
static inline uint64_t PocHistQuantile(const uint64_t *buckets, uint64_t total, double quantile)
{
    uint64_t rank;
    uint64_t seen;
    int      ii;

    if (total == 0)
        return 0;
    rank = (uint64_t)((double)total * quantile);
    if (rank >= total)
        rank = total - 1;
    seen = 0;
    for (ii = 0; ii < POC_HIST_BUCKETS; ii++)
    {
        seen += buckets[ii];
        if (seen > rank)
            return PocHistValue(ii);
    }
    return PocHistValue(POC_HIST_BUCKETS - 1);
}

#endif /* POC_WIRE_H */
