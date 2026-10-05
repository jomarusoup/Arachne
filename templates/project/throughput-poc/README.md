# throughput-poc — 스트림 수신 처리량 PoC

C 서버가 길이 prefix 바이너리 메시지를 TCP로 쏟아낼 때, 수신기가 목표 레이트를 버티는지 잰다.
수신기는 두 가지다. Node(`net`, Electron utility process와 같은 런타임)와 C 기준선이다.

측정 원칙은 `skills/load-testing/SKILL.md`가 정본이다.
송신은 개방 루프이고, 지연은 예정 송신 시각부터 잰다.

## 구성

| 경로 | 내용 |
|---|---|
| `common/poc_wire.h` | 와이어 형식, 단조 시계, 지연 히스토그램 (헤더 전용) |
| `sender/poc_sender.c` | 송신 시뮬레이터 — 접속한 클라이언트 하나에 목표 레이트로 송신 |
| `receiver-c/poc_receiver.c` | C 기준선 수신기 |
| `receiver-node/receiver.mjs` | Node 수신기 — 외부 npm 의존성 없음 |
| `report.mjs` | 결과 JSON → Markdown 표 |
| `run-poc.sh` | 레이트 × 수신기 조합을 차례로 돌리고 표를 출력 |
| `Makefile` | `make`(측정용 `-O2`), `make asan`(정확성 점검용), `make clean` |

## 실행

```bash
make                         # build/poc_sender, build/poc_receiver
./run-poc.sh                 # 1만·10만·100만 건/초, 64B, 10초, node·c
DURATION=5 ./run-poc.sh      # 짧게
RATES="2000000 5000000 10000000" RECEIVERS=node ./run-poc.sh   # 포화점 찾기
```

| 환경변수 | 기본값 | 뜻 |
|---|---|---|
| `RATES` | `10000 100000 1000000` | 목표 메시지/초 목록 |
| `MSG_SIZE` | `64` | payload 바이트 (최소 24). 와이어 프레임은 +4바이트 |
| `DURATION` | `10` | 레이트당 송신 시간(초) |
| `RECEIVERS` | `node c` | 돌릴 수신기 |
| `PORT_BASE` | `47100` | 첫 실행 포트. 실행마다 1씩 올린다 |
| `OUT_DIR` | `./results` | JSON·로그·`result.md` 저장 위치 |
| `NODE_BIN` | `node` | Electron 내장 Node로 재려면 그 경로를 준다 |

단독 실행도 된다.

```bash
./build/poc_sender -p 47100 -r 100000 -s 64 -d 10 -o send.json &
node receiver-node/receiver.mjs --port 47100 --out recv.json
```

## 와이어 형식

```
[u32 BE payload 길이][payload]
payload: u32 LE kind(1=DATA 2=HELLO 3=END) | u32 LE 0 | u64 LE field_a | u64 LE field_b | 0 채움
DATA : field_a = 시퀀스(0부터), field_b = 예정 송신 시각(시작 기준 상대 ns)
HELLO: field_a = 송신 시작 시각(단조 ns)
END  : field_a = 총 송신 건수
```

프레이밍은 `c-system/src/pipeline/frame_codec`과 같다.

## 표 읽는 법

| 열 | 뜻 |
|---|---|
| 달성(건/초) | 수신 건수 ÷ 첫 수신~마지막 수신 시간 |
| 수신 시간(초)/예정 | 예정보다 길면 수신기가 뒤처진 것이다 |
| 유실/갭 | 송신 총 건수 − 수신 건수 / 시퀀스 갭 횟수. TCP라 0이 정상이다 |
| p50·p99·p99.9·최대 | 수신 시각 − 예정 송신 시각. 송신기의 밀림도 포함된다 |
| 최대 RSS | 수신 프로세스 최대 상주 메모리 |
| 수신 CPU | 수신 프로세스 CPU 시간 ÷ 벽시계 시간. 100%에 붙으면 단일 스레드 포화다 |
| 송신 최대 밀림 | 송신기가 예정 시각보다 늦게 쓴 최대 시간. 크면 부하기 자체를 의심한다 |

버텼다는 판정은 세 가지가 함께 성립할 때다.
달성률이 100%이고, 수신 시간이 예정과 같고, p99가 ms 이하로 유지된다.
포화하면 수신 시간이 늘고 p99가 수백 ms~초로 뛴다.

지연 열이 "측정 안 함"이면 두 프로세스의 단조 시계가 다른 것이다.
수신 측은 HELLO 수신 시 시각 차가 0~1초 범위인지로 판정한다.
이때 처리량·갭·RSS·CPU는 그대로 유효하다.

## 한계

- 같은 호스트(localhost)에서 잰다. 네트워크 지연·대역폭·재전송이 빠져 있다.
- 수신기는 프레임 해석과 계측만 한다. 실제 클라이언트는 여기에 디코딩·상태 갱신·렌더러 전달 비용이 더해진다.
- 1시간 장시간 안정성은 `DURATION=3600 RATES=<요구치>`로 따로 잰다. 결과의 초당 RSS 열을 본다.
