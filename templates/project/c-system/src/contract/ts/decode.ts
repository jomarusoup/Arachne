/*#############################################################################
FILE NAME   : decode.ts
DESCRIPTION : stream_msg.h 정본의 TypeScript 디코더 — DataView 리틀엔디언 해석, 64비트 정수는 bigint
#############################################################################*/

/*-----------------------------------------------------------------------------
레이아웃 상수 — C 헤더(stream_msg.h)에서 옮겨 적은 값이다.
손으로 옮긴 값은 틀릴 수 있으므로 decode.test.ts 가 vectors/layout.json(헤더에서 생성)과
하나씩 대조한다. 대조가 이 파일의 증거다. 타입 검사 통과는 증거가 아니다.
-----------------------------------------------------------------------------*/
export const STREAM_MSG_VERSION  = 1;
export const STREAM_MSG_MAX_BODY = 4096;
export const STREAM_HEADER_SIZE  = 24;
export const STREAM_QUOTE_SIZE   = 48;
export const STREAM_KEY_LEN      = 16;
export const STREAM_PRICE_SCALE  = 10000n;
export const STREAM_QTY_SCALE    = 1000n;

export const STREAM_MSG_TYPE = {
    heartbeat: 0,
    quote:     1,
} as const;

export const HEADER_OFFSET = {
    version:    0,
    msgType:    2,
    bodyLen:    4,
    sequence:   8,
    sendTimeNs: 16,
} as const;

export const QUOTE_OFFSET = {
    key:      0,
    price:    16,
    qty:      24,
    flags:    32,
    reserved: 36,
} as const;

const LITTLE_ENDIAN = true;     /* 채널 계약: 모든 다중 바이트 필드는 리틀엔디언 */

export interface StreamMsgHeader {
    readonly version:    number;
    readonly msgType:    number;
    readonly bodyLen:    number;
    readonly sequence:   bigint;    /* u64 — Number 로 바꾸지 않는다 */
    readonly sendTimeNs: bigint;    /* i64 ns, Unix epoch UTC */
}

export interface StreamQuote {
    readonly key:   string;
    readonly price: bigint;         /* 가격 × STREAM_PRICE_SCALE */
    readonly qty:   bigint;         /* 수량 × STREAM_QTY_SCALE */
    readonly flags: number;
}

export type StreamMessage =
    | { readonly header: StreamMsgHeader; readonly kind: "heartbeat" }
    | { readonly header: StreamMsgHeader; readonly kind: "quote"; readonly quote: StreamQuote }
    | { readonly header: StreamMsgHeader; readonly kind: "unknown" };

/* C 쪽 음수 errno 와 같은 이름을 쓴다 — 양쪽 로그를 같은 말로 읽기 위해서다 */
export type DecodeErrorCode = "EMSGSIZE" | "EPROTO" | "EOVERFLOW" | "EBADMSG";

export class StreamDecodeError extends Error {
    readonly code: DecodeErrorCode;

    constructor(code: DecodeErrorCode, message: string) {
        super(`${code}: ${message}`);
        this.name = "StreamDecodeError";
        this.code = code;
    }
}

/*=============================================================================
FUNCTION    : DecodeHeader
DESCRIPTION : offset 위치의 헤더 24바이트를 해석하고 버전·본문 상한을 검사한다
PARAMETERS  : DataView view - 수신 버퍼
              number offset - 헤더 시작 위치
RETURNED    : StreamMsgHeader (실패 시 StreamDecodeError)
=============================================================================*/
export function DecodeHeader(view: DataView, offset: number): StreamMsgHeader {
    if (view.byteLength - offset < STREAM_HEADER_SIZE) {
        throw new StreamDecodeError("EMSGSIZE", "헤더보다 짧은 입력");
    }

    const header: StreamMsgHeader = {
        version:    view.getUint16(offset + HEADER_OFFSET.version, LITTLE_ENDIAN),
        msgType:    view.getUint16(offset + HEADER_OFFSET.msgType, LITTLE_ENDIAN),
        bodyLen:    view.getUint32(offset + HEADER_OFFSET.bodyLen, LITTLE_ENDIAN),
        sequence:   view.getBigUint64(offset + HEADER_OFFSET.sequence, LITTLE_ENDIAN),
        sendTimeNs: view.getBigInt64(offset + HEADER_OFFSET.sendTimeNs, LITTLE_ENDIAN),
    };

    if (header.version !== STREAM_MSG_VERSION) {
        throw new StreamDecodeError("EPROTO", `지원하지 않는 버전 ${header.version}`);
    }
    if (header.bodyLen > STREAM_MSG_MAX_BODY) {
        throw new StreamDecodeError("EOVERFLOW", `본문 상한 초과 ${header.bodyLen}`);
    }
    return header;
}

/*-----------------------------------------------------------------------------
키 해석 — ASCII, 첫 NUL 뒤는 모두 NUL 이어야 한다(C 디코더와 같은 규칙)
-----------------------------------------------------------------------------*/
function DecodeKey(view: DataView, offset: number): string {
    let key     = "";
    let seenNul = false;

    for (let ii = 0; ii < STREAM_KEY_LEN; ii++) {
        const byte = view.getUint8(offset + ii);

        if (byte === 0) {
            seenNul = true;
        } else if (seenNul || byte > 0x7f) {
            throw new StreamDecodeError("EBADMSG", "키 패딩 오염 또는 비 ASCII");
        } else {
            key += String.fromCharCode(byte);
        }
    }
    return key;
}

/*=============================================================================
FUNCTION    : DecodeQuote
DESCRIPTION : 본문을 StreamQuote 로 해석한다. 아는 크기 뒤의 바이트(미래 필드)는 무시한다
PARAMETERS  : DataView view    - 수신 버퍼
              number   offset  - 본문 시작 위치
              number   bodyLen - 헤더의 본문 길이
RETURNED    : StreamQuote (실패 시 StreamDecodeError)
=============================================================================*/
export function DecodeQuote(view: DataView, offset: number, bodyLen: number): StreamQuote {
    if (bodyLen < STREAM_QUOTE_SIZE || view.byteLength - offset < STREAM_QUOTE_SIZE) {
        throw new StreamDecodeError("EMSGSIZE", "본문이 StreamQuote 보다 짧다");
    }
    return {
        key:   DecodeKey(view, offset + QUOTE_OFFSET.key),
        price: view.getBigInt64(offset + QUOTE_OFFSET.price, LITTLE_ENDIAN),
        qty:   view.getBigInt64(offset + QUOTE_OFFSET.qty, LITTLE_ENDIAN),
        flags: view.getUint32(offset + QUOTE_OFFSET.flags, LITTLE_ENDIAN),
    };
}

/*=============================================================================
FUNCTION    : DecodeMessage
DESCRIPTION : 메시지 하나(헤더 + 본문)를 해석한다. 모르는 종류는 kind "unknown" 으로 넘겨
              호출자가 bodyLen 만큼 건너뛰게 한다(추가만 허용하는 진화 규칙)
PARAMETERS  : DataView view   - 수신 버퍼
              number   offset - 메시지 시작 위치
RETURNED    : StreamMessage
=============================================================================*/
export function DecodeMessage(view: DataView, offset: number): StreamMessage {
    const header = DecodeHeader(view, offset);
    const body   = offset + STREAM_HEADER_SIZE;

    if (view.byteLength - body < header.bodyLen) {
        throw new StreamDecodeError("EMSGSIZE", "본문이 아직 다 오지 않았다");
    }
    if (header.msgType === STREAM_MSG_TYPE.heartbeat) {
        return { header, kind: "heartbeat" };
    }
    if (header.msgType === STREAM_MSG_TYPE.quote) {
        return { header, kind: "quote", quote: DecodeQuote(view, body, header.bodyLen) };
    }
    return { header, kind: "unknown" };
}

/*=============================================================================
FUNCTION    : FormatScaled
DESCRIPTION : 스케일 정수를 소수 문자열로 바꾼다. 부동소수점을 거치지 않는다
PARAMETERS  : bigint value - 스케일 정수
              bigint scale - 10의 거듭제곱 (예: 10000n)
RETURNED    : 고정 소수점 문자열 (예: 1234500n, 10000n → "123.4500")
=============================================================================*/
export function FormatScaled(value: bigint, scale: bigint): string {
    const negative = value < 0n;
    const abs      = negative ? -value : value;
    const digits   = scale.toString().length - 1;
    const whole    = abs / scale;
    const frac     = (abs % scale).toString().padStart(digits, "0");
    const sign     = negative ? "-" : "";

    return digits === 0 ? `${sign}${whole}` : `${sign}${whole}.${frac}`;
}
