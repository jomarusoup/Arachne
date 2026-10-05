/*#############################################################################
FILE NAME   : report.mjs
DESCRIPTION : 처리량 PoC 결과 디렉터리(*.send.json·*.recv.json)를 읽어 Markdown 결과 표를 출력
#############################################################################*/

// 사용: node report.mjs <결과 디렉터리>

import { readdirSync, readFileSync, existsSync } from 'node:fs';
import { join } from 'node:path';

//=============================================================================
// FUNCTION    : FormatLatency
// DESCRIPTION : µs 값을 사람이 읽기 쉬운 단위로 바꾼다
//=============================================================================
function FormatLatency(micros, measured) {
    if (!measured) return '측정 안 함';
    if (micros >= 1_000_000) return `${(micros / 1_000_000).toFixed(2)} s`;
    if (micros >= 1000) return `${(micros / 1000).toFixed(1)} ms`;
    return `${micros} µs`;
}

function FormatCount(value) {
    return Math.round(value).toLocaleString('en-US');
}

function LoadRuns(dir) {
    const runs = [];
    for (const name of readdirSync(dir)) {
        if (!name.endsWith('.recv.json')) continue;
        const tag = name.slice(0, -'.recv.json'.length);
        const recv = JSON.parse(readFileSync(join(dir, name), 'utf8'));
        const sendPath = join(dir, `${tag}.send.json`);
        const send = existsSync(sendPath) ? JSON.parse(readFileSync(sendPath, 'utf8')) : null;
        runs.push({ tag, recv, send });
    }
    return runs.sort((lhs, rhs) => {
        const rateDiff = (lhs.send?.targetRate ?? 0) - (rhs.send?.targetRate ?? 0);
        return rateDiff !== 0 ? rateDiff : lhs.recv.receiver.localeCompare(rhs.recv.receiver);
    });
}

function BuildRow(run) {
    const { recv, send } = run;
    const target = send ? send.targetRate : 0;
    const sent = send ? send.sent : recv.expected;
    const lost = Math.max(0, sent - recv.received);
    const ratio = target > 0 ? `${((recv.throughput / target) * 100).toFixed(1)}%` : '-';
    const duration = send ? send.durationSec : 0;
    return [
        recv.receiver,
        FormatCount(target),
        FormatCount(recv.throughput),
        ratio,
        `${recv.activeSec.toFixed(2)} / ${duration}`,
        `${lost} / ${recv.gaps}`,
        FormatLatency(recv.p50Us, recv.latencyMeasured),
        FormatLatency(recv.p99Us, recv.latencyMeasured),
        FormatLatency(recv.p999Us, recv.latencyMeasured),
        FormatLatency(recv.maxUs, recv.latencyMeasured),
        `${recv.maxRssMb} MB`,
        `${recv.cpuPercent}%`,
        send ? FormatLatency(send.maxLagUs, true) : '-',
    ];
}

function Main() {
    const dir = process.argv[2];
    if (!dir) {
        process.stderr.write('usage: node report.mjs <results-dir>\n');
        process.exit(2);
    }
    const header = [
        '수신기', '목표(건/초)', '달성(건/초)', '달성률', '수신 시간(초)/예정',
        '유실/갭', 'p50', 'p99', 'p99.9', '최대', '최대 RSS', '수신 CPU', '송신 최대 밀림',
    ];
    const lines = [
        `| ${header.join(' | ')} |`,
        `| ${header.map(() => '---').join(' | ')} |`,
    ];
    for (const run of LoadRuns(dir)) lines.push(`| ${BuildRow(run).join(' | ')} |`);
    process.stdout.write(`${lines.join('\n')}\n`);
}

Main();
