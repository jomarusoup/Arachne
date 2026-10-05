# 공유메모리 복구 런북

> 공유메모리 장애는 **증상 → 판정 → 조치 → 검증 → 기록** 순서로 처리한다.
> 세그먼트 이름·소유 프로세스·pidfile 은 [shm-layout.md](shm-layout.md) 표에서 찾는다.
> 도구는 `tools/` 에서 `make` 로 만든다. 모든 쓰기 동작은 기본이 dry-run 이다.

## 0. 원칙

- 운영 서버에서는 **읽기 전용 확인부터** 한다(`status`·`--header`·`--verify-only`).
- 쓰기 조치(`--apply`) 전에 영향 범위를 적고 승인을 받는다. 승인자: ______
- 개인정보 필드는 보지 않는다. 꼭 봐야 하면 `--unmask "<티켓 번호와 사유>"` 로 감사 로그를 남긴다.
- 모든 명령은 실행 로그(`shmctl.log`, `--log` 로 지정한 복구 로그)를 남긴다. 로그를 지우지 않는다.

## 1. 증상

| 증상 | 어디서 보나 |
|---|---|
| 조회 실패: attach `-EIO`(손상)·`-EAGAIN`(초기화 중)·`-EPROTO`(버전 불일치) | 서비스 로그 |
| `ENOTRECOVERABLE`, `EOWNERDEAD` 복구 실패 | 워커 로그 |
| DB 대조 불일치(건수·체크섬·표본) | 정합성 대조 배치 |
| `load_seq` 가 오래 그대로, 시퀀스 락 홀수에서 멈춤 | `shmctl.sh status` 반복 |

## 2. 판정

```bash
# 헤더 요약과 attach 프로세스 수 — 레코드 내용은 출력하지 않는다
tools/shmctl.sh status /서비스_item --pidfile /var/run/서비스/loader.pid

# 손상 판정 — 매직·버전·레코드 크기·용량·상태·체크섬·정렬 불변식
tools/shm_recover --name /서비스_item --verify-only
```

| `--verify-only` 결과 | 판정 | 다음 |
|---|---|---|
| 종료 0, `verdict=OK` | 정상. 증상은 다른 곳 | 서비스·DB 쪽 조사 |
| `check.header=매직 불일치` 등 헤더 오류 | 헤더 손상 — 헤더 재작성 필요 | 3-B |
| `check.state=CORRUPT`, `check.checksum=mismatch`, `check.sorted=violation` | 데이터 손상 | 3-A |
| `check.state=RECOVERING` 이 계속 남음 | 복구 중 중단 | 3-A(`--force-reload`) |
| `check.state=INIT` 이 계속 남음 | 기동 적재 중 중단 | 3-A |

- 체크섬 불일치는 작성자가 쓰는 중에 읽으면 잠깐 보일 수 있다. **10초 뒤 한 번 더** 확인한다.
- `attach 실패 … --cap` 메시지가 나오면 헤더의 용량도 깨졌다. shm-layout.md 의 용량을 `--cap` 으로 준다.

## 3. 조치

### 3-A. 데이터 손상 — 원천에서 재적재

```bash
# 1) 미반영 더티 건수를 먼저 기록한다(재적재하면 사라진다)
# 2) 영향 없이 계획 확인 — 원천을 임시 영역에 읽어 정렬·중복·체크섬까지 검사한다
tools/shm_recover --name /서비스_item --source db:운영DB --dry-run
# 3) 실행 — 세그먼트 이름을 다시 입력하는 확인 프롬프트가 뜬다
tools/shm_recover --name /서비스_item --source db:운영DB --apply --log /var/log/서비스/shm_recover.log
```

- 상태 전이: `CORRUPT·READY → RECOVERING → READY`. 원천 적재·검증이 끝나기 전에는 세그먼트를 바꾸지 않는다.
- 중간에 실패하면 상태를 `CORRUPT` 로 둔다. 독자는 조회를 멈춘 상태로 남는다.
- DB 원천(`db:`)은 프로젝트의 `rec_loader_db.pc` 로 구현한다. DB 장애 중이면 검증된 덤프 파일을 `file:<경로>` 로 쓴다.

### 3-B. 헤더 손상 — 헤더 재작성 후 재적재

```bash
# 1) 소유·조회 프로세스를 모두 멈춘다(헤더 재작성은 뮤텍스도 다시 초기화한다)
# 2) 리눅스는 attach 프로세스가 남아 있으면 shm_recover 가 거부한다
tools/shmctl.sh status /서비스_item --pidfile /var/run/서비스/loader.pid
tools/shm_recover --name /서비스_item --source db:운영DB --dry-run
tools/shm_recover --name /서비스_item --source db:운영DB --apply
```

### 3-C. 다시 만들어야 할 때 — 삭제 후 재생성

레이아웃 버전·레코드 크기가 바뀌었거나 용량을 늘려야 할 때다.

```bash
# dry-run(기본): 안전 조건만 검사하고 지우지 않는다
tools/shmctl.sh remove /서비스_item --pidfile /var/run/서비스/loader.pid
# 실행: 소유 프로세스가 멈춰 있고 attach 가 0 이어야 하며, 이름 재입력 확인을 거친다
tools/shmctl.sh remove /서비스_item --pidfile /var/run/서비스/loader.pid --apply
# 소유 프로세스를 다시 띄우면 새로 만들고 적재한다
```

- macOS 처럼 attach 수를 셀 수 없는 환경에서는 `--pidfile` 이 없으면 거부한다.
- SysV 세그먼트는 대상에 `sysv:<shmid>` 를 쓴다(attach 수는 `ipcs` 의 nattch).

## 4. 검증

```bash
tools/shm_recover --name /서비스_item --verify-only          # 종료 0, verdict=OK
tools/shm_view --name /서비스_item --header                    # state=READY, rec_cnt, load_seq
tools/shm_view --name /서비스_item --range 1000 1010           # 표본 키 조회(마스킹 상태)
```

- [ ] `verdict=OK`, 상태 `READY`
- [ ] 건수가 DB `COUNT(*)` 와 같다(더티 제외)
- [ ] 표본 키 N개의 필드가 DB 와 같다
- [ ] 워커 로그에서 조회 오류가 멈췄다

## 5. 기록

| 항목 | 내용 |
|---|---|
| 일시(발생·인지·복구) | |
| 증상과 첫 로그 줄 | |
| 판정 근거(`--verify-only` 출력) | |
| 실행한 명령(그대로 복사) | |
| 결과(`result=` 줄, 건수·체크섬) | |
| 손실 범위(미반영 더티 건수) | |
| 원인과 재발 방지(재현 테스트 위치) | |
| 실행 로그 위치(`shmctl.log`·복구 로그·감사 로그) | |
