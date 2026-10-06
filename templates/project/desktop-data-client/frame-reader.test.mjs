/*#############################################################################
FILE NAME   : frame-reader.test.mjs
DESCRIPTION : FrameReader 재조립 계약 테스트 — 조각 입력·상한 초과·버퍼 재사용
#############################################################################*/

import { test } from "node:test";
import assert from "node:assert/strict";

import { FrameReader, FrameError, EncodeFrame } from "./frame-reader.mjs";

/*=============================================================================
FUNCTION    : Collect
DESCRIPTION : 콜백으로 받은 payload를 복사해 모은다 (뷰는 콜백 동안만 유효하다)
PARAMETERS  : FrameReader reader - 대상 리더
              Uint8Array[] chunks - 순서대로 넣을 조각
RETURNED    : 받은 payload 사본 배열
=============================================================================*/
function Collect(reader, chunks) {
    const frames = [];
    for (const chunk of chunks) {
        reader.Push(chunk, (bytes, offset, length) => {
            frames.push(Array.from(bytes.subarray(offset, offset + length)));
        });
    }
    return frames;
}

/*=============================================================================
FUNCTION    : Concat
DESCRIPTION : 바이트 배열 여러 개를 하나로 잇는다
PARAMETERS  : Uint8Array[] parts - 이을 배열
RETURNED    : 이어 붙인 새 Uint8Array
=============================================================================*/
function Concat(parts) {
    const total = parts.reduce((sum, part) => sum + part.length, 0);
    const out   = new Uint8Array(total);
    let   pos   = 0;
    for (const part of parts) {
        out.set(part, pos);
        pos += part.length;
    }
    return out;
}

const PAYLOADS = [
    Uint8Array.from([1, 2, 3]),
    Uint8Array.from([]),
    Uint8Array.from({ length: 300 }, (_, idx) => idx & 0xff),
    Uint8Array.from([9]),
];
const EXPECTED = PAYLOADS.map((payload) => Array.from(payload));
const STREAM   = Concat(PAYLOADS.map((payload) => EncodeFrame(payload)));

test("한_조각에_프레임_여러_개면_모두_순서대로_전달", () => {
    /* Arrange */
    const reader = new FrameReader({ maxFrame: 1024 });

    /* Act */
    const frames = Collect(reader, [STREAM]);

    /* Assert */
    assert.deepEqual(frames, EXPECTED);
    assert.equal(reader.BufferedBytes(), 0);
});

test("1바이트씩_넣어도_같은_프레임이_나온다", () => {
    /* Arrange */
    const reader = new FrameReader({ maxFrame: 1024, initialCapacity: 8 });
    const chunks = Array.from(STREAM, (byte) => Uint8Array.of(byte));

    /* Act */
    const frames = Collect(reader, chunks);

    /* Assert */
    assert.deepEqual(frames, EXPECTED);
});

test("임의_위치로_나눠도_같은_프레임이_나온다", () => {
    for (let seed = 1; seed <= 200; seed++) {
        /* Arrange — 결정적 의사 난수로 자를 위치를 고른다 */
        const reader = new FrameReader({ maxFrame: 1024, initialCapacity: 16 });
        const chunks = [];
        let   state  = seed;
        let   pos    = 0;
        while (pos < STREAM.length) {
            state = (state * 1103515245 + 12345) & 0x7fffffff;
            const len = 1 + (state % 97);
            chunks.push(STREAM.subarray(pos, pos + len));
            pos += len;
        }

        /* Act */
        const frames = Collect(reader, chunks);

        /* Assert */
        assert.deepEqual(frames, EXPECTED, `seed=${seed}`);
    }
});

test("상한_초과_길이는_본문을_기다리지_않고_오류_후_계속_거부", () => {
    /* Arrange — 헤더만 보낸다. 본문은 오지 않는다 */
    const reader = new FrameReader({ maxFrame: 16 });
    const header = Uint8Array.of(0, 0, 0, 17);

    /* Act + Assert */
    assert.throws(() => reader.Push(header, () => {}), FrameError);
    assert.equal(reader.IsFailed(), true);
    assert.throws(() => reader.Push(EncodeFrame(Uint8Array.of(1)), () => {}), FrameError);
});

test("리틀엔디언_옵션이면_길이를_리틀엔디언으로_읽는다", () => {
    /* Arrange */
    const reader = new FrameReader({ maxFrame: 64, littleEndian: true });
    const frame  = EncodeFrame(Uint8Array.of(7, 8), { littleEndian: true });

    /* Act */
    const frames = Collect(reader, [frame]);

    /* Assert */
    assert.deepEqual(frames, [[7, 8]]);
});

test("정상_상태에서는_버퍼를_재사용하고_더_키우지_않는다", () => {
    /* Arrange */
    const reader = new FrameReader({ maxFrame: 1024, initialCapacity: 64 });
    const frame  = EncodeFrame(Uint8Array.from({ length: 40 }, (_, idx) => idx));
    Collect(reader, [frame.subarray(0, 10), frame.subarray(10)]);
    const capacity = reader.Capacity();
    let   count    = 0;

    /* Act — 같은 크기 프레임을 두 조각으로 나눠 1만 번 넣는다 */
    for (let ii = 0; ii < 10000; ii++) {
        reader.Push(frame.subarray(0, 25), () => { count++; });
        reader.Push(frame.subarray(25), () => { count++; });
    }

    /* Assert */
    assert.equal(count, 10000);
    assert.equal(reader.Capacity(), capacity);
});

test("상한_크기_프레임은_버퍼를_상한까지만_키운다", () => {
    /* Arrange */
    const max_frame = 4096;
    const reader    = new FrameReader({ maxFrame: max_frame, initialCapacity: 16 });
    const payload   = new Uint8Array(max_frame).fill(0xab);

    /* Act */
    const frames = Collect(reader, [EncodeFrame(payload)]);

    /* Assert */
    assert.equal(frames.length, 1);
    assert.equal(frames[0].length, max_frame);
    assert.ok(reader.Capacity() <= max_frame + 4);
});

test("콜백이_던지면_리더는_실패_상태가_된다", () => {
    /* Arrange */
    const reader = new FrameReader({ maxFrame: 64 });

    /* Act + Assert */
    assert.throws(() => reader.Push(EncodeFrame(Uint8Array.of(1)), () => {
        throw new Error("처리기 오류");
    }), /처리기 오류/);
    assert.equal(reader.IsFailed(), true);
});

test("잘못된_생성_옵션은_즉시_거부", () => {
    assert.throws(() => new FrameReader({ maxFrame: 0 }), RangeError);
    assert.throws(() => new FrameReader({}), RangeError);
});
