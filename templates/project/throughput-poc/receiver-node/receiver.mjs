/*#############################################################################
FILE NAME   : receiver.mjs
DESCRIPTION : 처리량 PoC Node 수신기 — net 스트림 프레임 재조립(메시지별 할당 없음), 갭·지연·RSS·CPU 계측
#############################################################################*/

// Electron utility process 와 같은 Node 런타임에서 돈다. 외부 npm 의존성 없음.
// 사용: node receiver.mjs [--host 127.0.0.1] [--port 47100] [--out summary.json]

import net from 'node:net';
import { writeFileSync } from 'node:fs';
import { PerformanceObserver } from 'node:perf_hooks';

//-----------------------------------------------------------------------------
// 와이어 형식 — common/poc_wire.h 와 같다
// [u32 BE payload 길이][u32 LE kind][u32 LE 0][u64 LE field_a][u64 LE field_b][0 채움]
//-----------------------------------------------------------------------------
const FRAME_HEADER = 4;
const MIN_PAYLOAD = 24;
const MAX_PAYLOAD = 65536;
const KIND_DATA = 1;
const KIND_HELLO = 2;
const KIND_END = 3;
const TWO_POW_32 = 4294967296;
const CLOCK_SANITY_NS = 1_000_000_000n;
const INITIAL_BUF_BYTES = 1 << 20;
const CONNECT_RETRIES = 100;
const CONNECT_BACKOFF_MS = 50;
const HIST_BUCKETS = 1792;

//=============================================================================
// FUNCTION    : ParseArgs
// DESCRIPTION : --host/--port/--out 인자를 해석한다
// RETURNED    : { host, port, outPath }
//=============================================================================
function ParseArgs(argv) {
    const options = { host: '127.0.0.1', port: 47100, outPath: null };
    for (let ii = 0; ii < argv.length; ii += 2) {
        const key = argv[ii];
        const value = argv[ii + 1];
        if (key === '--host') options.host = value;
        else if (key === '--port') options.port = Number(value);
        else if (key === '--out') options.outPath = value;
        else throw new Error(`unknown option: ${key}`);
    }
    if (!Number.isInteger(options.port) || options.port <= 0 || options.port > 65535) {
        throw new Error('invalid --port');
    }
    return options;
}

//=============================================================================
// FUNCTION    : HistIndex / HistValue
// DESCRIPTION : µs 로그-선형 히스토그램 버킷 — poc_wire.h PocHistIndex/PocHistValue 와 같은 식
//=============================================================================
function HistIndex(micros) {
    let value = micros > 0xffffffff ? 0xffffffff : micros;
    if (value < 128) return value;
    value >>>= 0;
    const topBit = 31 - Math.clz32(value);
    const shift = topBit - 6;
    return 64 * shift + (value >>> shift);
}

function HistValue(index) {
    if (index < 128) return index;
    const shift = Math.floor(index / 64) - 1;
    const mantissa = index - 64 * shift;
    return mantissa * 2 ** shift;
}

function HistQuantile(buckets, total, quantile) {
    if (total === 0) return 0;
    const rank = Math.min(total - 1, Math.floor(total * quantile));
    let seen = 0;
    for (let ii = 0; ii < HIST_BUCKETS; ii++) {
        seen += buckets[ii];
        if (seen > rank) return HistValue(ii);
    }
    return HistValue(HIST_BUCKETS - 1);
}

//-----------------------------------------------------------------------------
// 수신 상태 — 메시지마다 객체를 만들지 않도록 모듈 범위 변수로 둔다
//-----------------------------------------------------------------------------
const histogram = new Float64Array(HIST_BUCKETS);
let pending = Buffer.allocUnsafe(INITIAL_BUF_BYTES);   // 재사용·확장 버퍼
let pendingLen = 0;
let received = 0;
let expected = 0;
let nextSeq = 0;
let gaps = 0;
let gapMessages = 0;
let outOfOrder = 0;
let startNsBig = 0n;          // 송신 측 시작 시각(BigInt, HELLO 1회만)
let latencyMeasured = false;
let clockOffsetNs = 0n;
let sawHello = false;
let sawEnd = false;
let firstDataRelNs = -1;
let lastDataRelNs = 0;
let maxRssBytes = 0;
let secondCount = 0;
const perSecond = [];
const gcPauses = { count: 0, totalMs: 0, maxMs: 0 };

//=============================================================================
// FUNCTION    : ReadU64AsNumber
// DESCRIPTION : u64 LE 를 Number 로 읽는다. readBigUInt64LE 는 메시지마다 BigInt 를 할당하므로
//               두 u32 로 읽어 합친다 (2^53 미만 값 — 시퀀스·상대 ns 에 충분)
//=============================================================================
function ReadU64AsNumber(buf, offset) {
    return buf.readUInt32LE(offset + 4) * TWO_POW_32 + buf.readUInt32LE(offset);
}

//=============================================================================
// FUNCTION    : HandleFrame
// DESCRIPTION : 완성 프레임 하나를 해석한다. nowRelNs 는 이 chunk 의 수신 시각(송신 시작 기준 ns)
//=============================================================================
function HandleFrame(buf, offset, len, nowNsBig, nowRelNs) {
    if (len < MIN_PAYLOAD) return;
    const kind = buf.readUInt32LE(offset);
    if (kind === KIND_HELLO) {
        sawHello = true;
        startNsBig = buf.readBigUInt64LE(offset + 8);
        clockOffsetNs = nowNsBig - startNsBig;
        latencyMeasured = clockOffsetNs >= 0n && clockOffsetNs < CLOCK_SANITY_NS;
        return;
    }
    if (kind === KIND_END) {
        sawEnd = true;
        expected = ReadU64AsNumber(buf, offset + 8);
        return;
    }
    if (kind !== KIND_DATA) return;

    const seq = ReadU64AsNumber(buf, offset + 8);
    if (firstDataRelNs < 0) firstDataRelNs = nowRelNs;
    lastDataRelNs = nowRelNs;
    received++;
    secondCount++;
    if (seq > nextSeq) {
        gaps++;
        gapMessages += seq - nextSeq;
    } else if (seq < nextSeq) {
        outOfOrder++;
    }
    if (seq >= nextSeq) nextSeq = seq + 1;

    if (latencyMeasured) {
        const schedRelNs = ReadU64AsNumber(buf, offset + 16);
        const latencyNs = nowRelNs > schedRelNs ? nowRelNs - schedRelNs : 0;
        histogram[HistIndex(Math.floor(latencyNs / 1000))]++;
    }
}

//=============================================================================
// FUNCTION    : AppendChunk
// DESCRIPTION : chunk 를 재사용 버퍼 뒤에 붙인다. 모자라면 2배로 키운다(드물게만 할당)
//=============================================================================
function AppendChunk(chunk) {
    const need = pendingLen + chunk.length;
    if (need > pending.length) {
        let capacity = pending.length * 2;
        while (capacity < need) capacity *= 2;
        const grown = Buffer.allocUnsafe(capacity);
        pending.copy(grown, 0, 0, pendingLen);
        pending = grown;
    }
    chunk.copy(pending, pendingLen);
    pendingLen = need;
}

//=============================================================================
// FUNCTION    : OnData
// DESCRIPTION : 소켓 chunk 를 받아 완성된 프레임을 모두 처리하고, 남은 조각을 앞으로 당긴다
//=============================================================================
function OnData(chunk) {
    const nowNsBig = process.hrtime.bigint();
    // BigInt 연산은 chunk 당 1회만 한다 — 메시지 단위 계산은 Number 로
    let nowRelNs = sawHello ? Number(nowNsBig - startNsBig) : 0;
    AppendChunk(chunk);

    let offset = 0;
    while (pendingLen - offset >= FRAME_HEADER) {
        const len = pending.readUInt32BE(offset);
        if (len > MAX_PAYLOAD) throw new Error(`frame too large: ${len}`);
        if (pendingLen - offset < FRAME_HEADER + len) break;
        const helloBefore = sawHello;
        HandleFrame(pending, offset + FRAME_HEADER, len, nowNsBig, nowRelNs);
        // 같은 chunk 안에서 HELLO 뒤에 오는 DATA 는 방금 받은 기준 시각을 써야 한다
        if (!helloBefore && sawHello) nowRelNs = Number(nowNsBig - startNsBig);
        offset += FRAME_HEADER + len;
    }
    if (offset > 0) {
        pending.copy(pending, 0, offset, pendingLen);
        pendingLen -= offset;
    }
}

//=============================================================================
// FUNCTION    : ConnectWithRetry
// DESCRIPTION : 송신기가 listen 할 때까지 재시도하며 연결한다
// RETURNED    : Promise<net.Socket>
//=============================================================================
function ConnectWithRetry(host, port, triesLeft) {
    return new Promise((resolve, reject) => {
        const socket = net.connect({ host, port });
        socket.once('connect', () => resolve(socket));
        socket.once('error', (err) => {
            socket.destroy();
            if (triesLeft <= 0) {
                reject(err);
                return;
            }
            setTimeout(() => {
                ConnectWithRetry(host, port, triesLeft - 1).then(resolve, reject);
            }, CONNECT_BACKOFF_MS);
        });
    });
}

function SampleSecond(elapsedSec) {
    const rss = process.memoryUsage.rss();
    if (rss > maxRssBytes) maxRssBytes = rss;
    perSecond.push({ t: elapsedSec, msgs: secondCount, rssMb: +(rss / 1048576).toFixed(1) });
    process.stderr.write(`[receiver.mjs] t=${elapsedSec}s ${secondCount} msg/s rss=${(rss / 1048576).toFixed(1)}MB\n`);
    secondCount = 0;
}

//=============================================================================
// FUNCTION    : BuildSummary
// DESCRIPTION : poc_receiver.c 와 같은 키의 요약 객체를 만든다
//=============================================================================
function BuildSummary(wallSec, cpuUsage) {
    let latencyTotal = 0;
    for (let ii = 0; ii < HIST_BUCKETS; ii++) latencyTotal += histogram[ii];
    const activeSec = firstDataRelNs >= 0 ? (lastDataRelNs - firstDataRelNs) / 1e9 : 0;
    const cpuSec = (cpuUsage.user + cpuUsage.system) / 1e6;
    return {
        role: 'receiver',
        receiver: 'node',
        nodeVersion: process.version,
        received,
        expected,
        sawEnd,
        gaps,
        gapMessages,
        outOfOrder,
        activeSec: +activeSec.toFixed(3),
        throughput: activeSec > 0 ? Math.round(received / activeSec) : 0,
        latencyMeasured,
        clockOffsetUs: Number(clockOffsetNs / 1000n),
        p50Us: HistQuantile(histogram, latencyTotal, 0.5),
        p99Us: HistQuantile(histogram, latencyTotal, 0.99),
        p999Us: HistQuantile(histogram, latencyTotal, 0.999),
        maxUs: HistQuantile(histogram, latencyTotal, 1.0),
        maxRssMb: +(maxRssBytes / 1048576).toFixed(1),
        cpuPercent: wallSec > 0 ? +((cpuSec / wallSec) * 100).toFixed(1) : 0,
        wallSec: +wallSec.toFixed(3),
        gc: { count: gcPauses.count, totalMs: +gcPauses.totalMs.toFixed(1), maxMs: +gcPauses.maxMs.toFixed(2) },
        perSecond,
    };
}

async function Main() {
    const options = ParseArgs(process.argv.slice(2));
    const gcObserver = new PerformanceObserver((list) => {
        for (const entry of list.getEntries()) {
            gcPauses.count++;
            gcPauses.totalMs += entry.duration;
            if (entry.duration > gcPauses.maxMs) gcPauses.maxMs = entry.duration;
        }
    });
    gcObserver.observe({ entryTypes: ['gc'] });

    const socket = await ConnectWithRetry(options.host, options.port, CONNECT_RETRIES);
    const beginNs = process.hrtime.bigint();
    const cpuBegin = process.cpuUsage();
    let elapsedSec = 0;
    const ticker = setInterval(() => SampleSecond(++elapsedSec), 1000);

    socket.on('data', OnData);
    socket.on('error', (err) => process.stderr.write(`[receiver.mjs] socket error: ${err.message}\n`));
    socket.on('close', () => {
        clearInterval(ticker);
        gcObserver.disconnect();
        const rss = process.memoryUsage.rss();
        if (rss > maxRssBytes) maxRssBytes = rss;
        const wallSec = Number(process.hrtime.bigint() - beginNs) / 1e9;
        const summary = BuildSummary(wallSec, process.cpuUsage(cpuBegin));
        const text = `${JSON.stringify(summary)}\n`;
        if (options.outPath) writeFileSync(options.outPath, text);
        else process.stdout.write(text);
    });
}

Main().catch((err) => {
    process.stderr.write(`[receiver.mjs] ${err.message}\n`);
    process.exit(1);
});
