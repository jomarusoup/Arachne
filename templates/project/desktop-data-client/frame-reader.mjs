/*#############################################################################
FILE NAME   : frame-reader.mjs
DESCRIPTION : 길이 prefix 프레임 재조립기 — 재사용 버퍼·DataView, 부분 수신, 최대 프레임 상한
#############################################################################*/

/*-----------------------------------------------------------------------------
와이어 형식
[4바이트 payload 길이][payload]
기본 엔디언은 빅엔디언이다. templates/project/c-system/src/pipeline/frame_codec.h와 같다.
길이 0 프레임은 하트비트로 보고 그대로 전달한다.
엔디언과 최대 크기의 정본은 채널 계약(api-contracts 스킬)이다.
-----------------------------------------------------------------------------*/
export const FRAME_HEADER_SIZE = 4;

const DEFAULT_INITIAL_CAPACITY = 64 * 1024;

/*-----------------------------------------------------------------------------
스트림 동기를 잃은 오류. 받은 쪽은 다시 맞추지 말고 연결을 끊는다.
-----------------------------------------------------------------------------*/
export class FrameError extends Error {
    constructor(message, code) {
        super(message);
        this.name = "FrameError";
        this.code = code;
    }
}

export class FrameReader {
    #buf;
    #view;
    #read   = 0;
    #write  = 0;
    #failed = false;
    #maxFrame;
    #littleEndian;

    /*=========================================================================
    FUNCTION    : constructor
    DESCRIPTION : 상한과 엔디언을 고정하고 재사용 버퍼를 미리 할당한다
    PARAMETERS  : number options.maxFrame        - payload 최대 바이트 (필수, 1 이상)
                  number options.initialCapacity - 처음 버퍼 크기 (기본 64KiB, 상한으로 잘린다)
                  boolean options.littleEndian   - 길이 필드 엔디언 (기본 false = 빅엔디언)
    =========================================================================*/
    constructor({ maxFrame, initialCapacity = DEFAULT_INITIAL_CAPACITY, littleEndian = false } = {}) {
        if (!Number.isInteger(maxFrame) || maxFrame < 1 || maxFrame > 0xffffffff) {
            throw new RangeError("maxFrame은 1 이상 2^32-1 이하의 정수여야 한다");
        }
        const upper    = maxFrame + FRAME_HEADER_SIZE;
        const capacity = Math.min(Math.max(initialCapacity, FRAME_HEADER_SIZE * 2), upper);

        this.#maxFrame     = maxFrame;
        this.#littleEndian = littleEndian;
        this.#buf          = new Uint8Array(capacity);
        this.#view         = new DataView(this.#buf.buffer);
    }

    /*=========================================================================
    FUNCTION    : Push
    DESCRIPTION : 받은 조각을 버퍼에 이어 붙이고 완성된 프레임마다 onFrame을 부른다.
                  onFrame에 넘기는 bytes·view는 내부 버퍼다. 콜백 동안만 유효하다.
                  상한 초과나 콜백 예외가 나면 실패 상태가 되고 이후 Push는 모두 거부한다.
    PARAMETERS  : Uint8Array chunk  - 소켓에서 받은 조각 (Node Buffer도 된다)
                  function onFrame  - (bytes, offset, length, view) => void
    RETURNED    : 이번 호출에서 전달한 프레임 수
    =========================================================================*/
    Push(chunk, onFrame) {
        if (this.#failed) {
            throw new FrameError("실패 상태의 리더다. 연결을 끊고 새 리더를 만든다", "EFAILED");
        }
        let pos   = 0;
        let count = 0;
        try {
            while (pos < chunk.length) {
                this.#Compact();
                if (this.#write === this.#buf.length) {
                    this.#Grow();
                }
                const take = Math.min(this.#buf.length - this.#write, chunk.length - pos);
                this.#buf.set(chunk.subarray(pos, pos + take), this.#write);
                this.#write += take;
                pos         += take;
                count       += this.#Drain(onFrame);
            }
        } catch (error) {
            this.#failed = true;
            throw error;
        }
        return count;
    }

    IsFailed()      { return this.#failed; }
    Capacity()      { return this.#buf.length; }
    BufferedBytes() { return this.#write - this.#read; }

    /*=========================================================================
    FUNCTION    : #Drain
    DESCRIPTION : 버퍼 안의 완성 프레임을 모두 전달한다. 길이는 읽는 즉시 상한과 비교한다.
    PARAMETERS  : function onFrame - 프레임 콜백
    RETURNED    : 전달한 프레임 수
    =========================================================================*/
    #Drain(onFrame) {
        let count = 0;
        while (this.#write - this.#read >= FRAME_HEADER_SIZE) {
            const length = this.#view.getUint32(this.#read, this.#littleEndian);
            if (length > this.#maxFrame) {
                throw new FrameError(`프레임 길이 ${length} > 상한 ${this.#maxFrame}`, "EFRAMESIZE");
            }
            if (this.#write - this.#read - FRAME_HEADER_SIZE < length) {
                break;   /* 본문이 아직 다 오지 않았다 */
            }
            onFrame(this.#buf, this.#read + FRAME_HEADER_SIZE, length, this.#view);
            this.#read += FRAME_HEADER_SIZE + length;
            count++;
        }
        if (this.#read === this.#write) {
            this.#read  = 0;
            this.#write = 0;
        }
        return count;
    }

    /*=========================================================================
    FUNCTION    : #Compact
    DESCRIPTION : 소비한 앞부분을 버리고 남은 부분 프레임을 버퍼 앞으로 옮긴다
    =========================================================================*/
    #Compact() {
        if (this.#read === 0) {
            return;
        }
        this.#buf.copyWithin(0, this.#read, this.#write);
        this.#write -= this.#read;
        this.#read   = 0;
    }

    /*=========================================================================
    FUNCTION    : #Grow
    DESCRIPTION : 버퍼가 부분 프레임 하나로 가득 찼을 때만 키운다. 상한 + 헤더를 넘지 않는다.
    =========================================================================*/
    #Grow() {
        const upper  = this.#maxFrame + FRAME_HEADER_SIZE;
        const needed = this.#write >= FRAME_HEADER_SIZE
            ? FRAME_HEADER_SIZE + this.#view.getUint32(0, this.#littleEndian)
            : FRAME_HEADER_SIZE;
        const next   = Math.min(Math.max(this.#buf.length * 2, needed), upper);
        const grown  = new Uint8Array(next);

        grown.set(this.#buf.subarray(0, this.#write));
        this.#buf  = grown;
        this.#view = new DataView(grown.buffer);
    }
}

/*=============================================================================
FUNCTION    : EncodeFrame
DESCRIPTION : payload 앞에 길이 헤더를 붙인 새 프레임을 만든다 (테스트·시뮬레이터용)
PARAMETERS  : Uint8Array payload           - 본문
              boolean options.littleEndian - 길이 필드 엔디언 (기본 false)
RETURNED    : 헤더 + payload 새 Uint8Array
=============================================================================*/
export function EncodeFrame(payload, { littleEndian = false } = {}) {
    const out = new Uint8Array(FRAME_HEADER_SIZE + payload.length);
    new DataView(out.buffer).setUint32(0, payload.length, littleEndian);
    out.set(payload, FRAME_HEADER_SIZE);
    return out;
}
