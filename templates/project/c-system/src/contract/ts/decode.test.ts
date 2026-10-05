/*#############################################################################
FILE NAME   : decode.test.ts
DESCRIPTION : C 가 만든 벡터로 TS 디코더를 검증 — 레이아웃 매니페스트 대조, 벡터 값 비교, 거부 경로
#############################################################################*/
/* 실행: node --test ts/decode.test.ts (Node 22.18+ / 23.6+ 는 타입 제거가 기본, 그 아래는 --experimental-strip-types) */

import { strict as assert } from "node:assert";
import { readFileSync } from "node:fs";
import { test } from "node:test";

import {
    DecodeHeader,
    DecodeMessage,
    FormatScaled,
    HEADER_OFFSET,
    QUOTE_OFFSET,
    STREAM_HEADER_SIZE,
    STREAM_MSG_MAX_BODY,
    STREAM_MSG_TYPE,
    STREAM_MSG_VERSION,
    STREAM_PRICE_SCALE,
    STREAM_QTY_SCALE,
    STREAM_QUOTE_SIZE,
    StreamDecodeError,
} from "./decode.ts";

const VECTOR_DIR = new URL("../vectors/", import.meta.url);

interface FieldEntry { name: string; offset: number; size: number; type: string; }
interface StructEntry { size: number; fields: FieldEntry[]; }
interface Layout {
    version: number;
    endian: string;
    maxBody: number;
    priceScale: number;
    qtyScale: number;
    msgTypes: Record<string, number>;
    structs: Record<string, StructEntry>;
}
interface CaseEntry {
    file: string;
    msgType: number;
    bodyLen: number;
    sequence: string;
    sendTimeNs: string;
    quote?: { key: string; price: string; qty: string; flags: number };
}

function ReadJson<T>(name: string): T {
    return JSON.parse(readFileSync(new URL(name, VECTOR_DIR), "utf8")) as T;
}

/* 파일 내용을 새 버퍼로 복사한다 — Buffer 풀을 공유하지 않아 offset 0 이 메시지 시작이다 */
function ReadBytes(name: string): Uint8Array {
    return new Uint8Array(readFileSync(new URL(name, VECTOR_DIR)));
}

function ReadView(name: string): DataView {
    return new DataView(ReadBytes(name).buffer);
}

function OffsetsOf(entry: StructEntry): Record<string, number> {
    return Object.fromEntries(entry.fields.map((field) => [field.name, field.offset]));
}

test("레이아웃: TS 상수가 C 헤더에서 생성한 매니페스트와 같다", () => {
    const layout = ReadJson<Layout>("layout.json");
    const header = layout.structs["StreamMsgHeader"];
    const quote  = layout.structs["StreamQuote"];

    assert.equal(layout.endian, "little");
    assert.equal(layout.version, STREAM_MSG_VERSION);
    assert.equal(layout.maxBody, STREAM_MSG_MAX_BODY);
    assert.equal(BigInt(layout.priceScale), STREAM_PRICE_SCALE);
    assert.equal(BigInt(layout.qtyScale), STREAM_QTY_SCALE);
    assert.deepEqual(layout.msgTypes, { ...STREAM_MSG_TYPE });
    assert.equal(header?.size, STREAM_HEADER_SIZE);
    assert.equal(quote?.size, STREAM_QUOTE_SIZE);
    assert.deepEqual(OffsetsOf(header!), { ...HEADER_OFFSET });
    assert.deepEqual(OffsetsOf(quote!), { ...QUOTE_OFFSET });
});

test("벡터: C 인코더가 쓴 메시지를 TS 가 같은 값으로 읽는다", () => {
    const { cases } = ReadJson<{ cases: CaseEntry[] }>("cases.json");

    assert.ok(cases.length >= 4, "벡터가 비어 있으면 검증이 아니다");
    for (const expected of cases) {
        const message = DecodeMessage(ReadView(expected.file), 0);

        assert.equal(message.header.msgType, expected.msgType, expected.file);
        assert.equal(message.header.bodyLen, expected.bodyLen, expected.file);
        assert.equal(message.header.sequence, BigInt(expected.sequence), expected.file);
        assert.equal(message.header.sendTimeNs, BigInt(expected.sendTimeNs), expected.file);

        if (expected.quote === undefined) {
            assert.equal(message.kind, "heartbeat", expected.file);
            continue;
        }
        assert.equal(message.kind, "quote", expected.file);
        if (message.kind !== "quote") {
            continue;
        }
        assert.equal(message.quote.key, expected.quote.key, expected.file);
        assert.equal(message.quote.price, BigInt(expected.quote.price), expected.file);
        assert.equal(message.quote.qty, BigInt(expected.quote.qty), expected.file);
        assert.equal(message.quote.flags, expected.quote.flags, expected.file);
    }
});

test("정밀도: 2^53 을 넘는 값이 Number 를 거치지 않고 보존된다", () => {
    const message = DecodeMessage(ReadView("quote_extreme.bin"), 0);

    assert.equal(message.header.sendTimeNs, 9007199254740993n);
    assert.equal(message.header.sequence, 18446744073709551615n);
    assert.equal(FormatScaled(1234500n, STREAM_PRICE_SCALE), "123.4500");
    assert.equal(FormatScaled(-250000n, STREAM_PRICE_SCALE), "-25.0000");
    assert.equal(FormatScaled(-9223372036854775808n, STREAM_PRICE_SCALE), "-922337203685477.5808");
});

test("거부: 짧은 입력·미래 버전·본문 상한·키 오염", () => {
    const source = ReadBytes("quote_basic.bin");
    const expectCode = (bytes: Uint8Array, code: string): void => {
        assert.throws(
            () => DecodeMessage(new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength), 0),
            (error: unknown) => error instanceof StreamDecodeError && error.code === code,
        );
    };

    expectCode(source.subarray(0, STREAM_HEADER_SIZE - 1), "EMSGSIZE");
    expectCode(source.subarray(0, STREAM_HEADER_SIZE + 10), "EMSGSIZE");

    const future = source.slice();
    future[HEADER_OFFSET.version] = 2;
    expectCode(future, "EPROTO");

    const huge = source.slice();
    huge[HEADER_OFFSET.bodyLen + 2] = 0x01;
    expectCode(huge, "EOVERFLOW");

    const dirty = source.slice();
    dirty[STREAM_HEADER_SIZE + QUOTE_OFFSET.key + 7] = 0x58;   /* "ALPHA\0\0X" */
    expectCode(dirty, "EBADMSG");
});

test("진화: 모르는 메시지 종류는 오류가 아니라 건너뛸 대상이다", () => {
    const unknown = ReadBytes("heartbeat.bin");
    unknown[HEADER_OFFSET.msgType] = 99;

    const view    = new DataView(unknown.buffer);
    const message = DecodeMessage(view, 0);

    assert.equal(message.kind, "unknown");
    assert.equal(DecodeHeader(view, 0).bodyLen, 0);
});
