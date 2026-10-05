---
name: shm-db-patterns
description: 실시간 데이터를 공유메모리에 두고 Oracle·PostgreSQL과 동기화하는 C 서버 패턴. POSIX shm_open+mmap vs SysV shmget 비교(이름·권한·정리·ipcs 가시성), 크기 산정·huge page 판단, 세그먼트 헤더(매직·레이아웃 버전·레코드 크기·건수·생성 시각·상태 플래그 INIT/READY/RECOVERING/CORRUPT·적재 시퀀스·체크섬) attach 검증, robust 프로세스 공유 뮤텍스(EOWNERDEAD → 검증·복구 → pthread_mutex_consistent) vs 단일 작성자 + 시퀀스 락, DB → 공유메모리 적재(Pro*C 호스트 배열 fetch → 임시 영역 → 검증 → 상태 전환), 공유메모리 → DB 반영(더티 플래그·변경 큐·배치 update·체크포인트·재시도), 정합성 대조, 금지 사항, 수명·권한, 복구 런북. 대상 경로 — **/*.c, **/*.h, **/*.pc, **/*.pgc. 키워드 — 공유메모리, shm_open, shmget, robust mutex, EOWNERDEAD, 시퀀스 락, 세그먼트 헤더, DB 적재, write-back, 복구 런북.
---

# 공유메모리 ⇄ DB — 실시간 데이터 계층

실시간 데이터는 공유메모리에 두고, DB를 정본 저장소로 둔다.
공유메모리는 **DB에서 언제든 다시 만들 수 있는 사본**이어야 한다. 그래야 손상되어도 복구할 수 있다.
모든 attach는 헤더를 검증하고, 모든 변경은 정해진 동기화 방식 하나를 따른다.

동작하는 예제는 `templates/project/c-system/src/shm/`에 있다.
`shm_segment.h`·`shm_segment.c`가 헤더·attach 검증·robust 뮤텍스·상태 전환의 기준 구현이다.
레코드와 정렬 조회는 `c-data-structures` 스킬과 `sorted_table.*`을 따른다.

## 언제 사용하나

- 여러 프로세스가 같은 실시간 데이터를 읽고 쓰는 구조를 설계할 때
- 기동 시 DB 데이터를 공유메모리로 올리거나, 변경분을 DB에 되돌려 쓸 때
- 프로세스가 락을 쥔 채 죽은 뒤의 복구 절차를 정할 때
- 운영 중 공유메모리 손상·불일치를 판정하고 복구할 때

### 언제 사용하지 않나

- 한 프로세스 안의 스레드 간 공유 → 메시지 패싱이 기본이다(`rules/systems/philosophy.md` 11절)
- 레코드 구조·정렬·조회 API → `c-data-structures`
- Pro*C·ecpg 문법과 SQLCA 처리 → `embedded-sql`
- 개인정보 필드의 적재·마스킹 기준 → `sensitive-data-handling`

## 방식 선택 — POSIX 기본, SysV 자산은 유지

새로 만드는 세그먼트는 POSIX(`shm_open` + `mmap`)를 쓴다. 이미 SysV(`shmget`)로 운영 중인 세그먼트는 그대로 둔다.
두 방식을 한 데이터에 섞지 않는다.

| 항목 | POSIX `shm_open` + `mmap` | SysV `shmget` + `shmat` |
|---|---|---|
| 이름 | `"/app_item"` 같은 문자열. 리눅스에서는 `/dev/shm/app_item` 파일로 보인다 | `key_t` 정수(`ftok` 또는 고정값). 충돌을 사람이 관리한다 |
| 권한 | `shm_open`의 mode와 `umask`. `ls -l /dev/shm`으로 확인 | `shmget` 플래그 하위 9비트. `ipcs -m`으로 확인, `shmctl(IPC_SET)`로 변경 |
| 크기 | `ftruncate`로 정한다 | 생성 시 고정. 바꾸려면 다시 만든다 |
| 정리 | `shm_unlink`. 이름이 지워지고 마지막 `munmap` 뒤 해제 | `shmctl(IPC_RMID)`. 마지막 `shmdt` 뒤 해제. 잊으면 재부팅까지 남는다 |
| 가시성 | `ls /dev/shm`. `ipcs`에는 안 보인다 | `ipcs -m`에 소유자·권한·attach 수(`nattch`)가 보인다 |
| attach 수 | 직접 알 수 없다(`/proc/<pid>/maps`·`lsof`) | `shm_nattch`로 바로 안다 |
| huge page | hugetlbfs에 만든 파일을 `mmap` | `SHM_HUGETLB` 플래그 |

- 운영 도구(`shmctl.sh`·`shm_view`)는 두 방식을 모두 다룬다.
- macOS는 POSIX 이름이 31자 이하이고 `fstat` 크기를 페이지 단위로 올려 보고한다. 예제는 이를 감안한다.

### 크기 산정

- 크기 = 헤더(128바이트) + 레코드 크기 × 최대 건수다. 예제의 `ShmSegCalcSize`가 넘침까지 검사한다.
- 최대 건수는 예상 최대치에 여유(1.3~1.5배)를 곱해 정한다. 늘리려면 세그먼트를 다시 만들어야 한다.
- `/dev/shm`은 tmpfs이고 기본 상한은 물리 메모리의 절반이다. 모든 세그먼트 합계를 그 안에서 계산한다.
- 공유메모리는 `free`의 `shared`·`/proc/meminfo`의 `Shmem`으로 집계된다. 감시 대상에 넣는다.

### huge page 판단

- 기본은 쓰지 않는다. 예약(`vm.nr_hugepages`)·마운트·권한 관리가 운영 부담이다.
- 세그먼트가 수백 MB 이상이고, `perf`로 dTLB 미스가 병목임을 측정했을 때만 검토한다.
- 쓰면 크기를 huge page 단위(보통 2 MiB)로 올리고, 예약이 모자라 생성이 실패하는 경로를 처리한다.

## 세그먼트 헤더 — attach할 때마다 검증한다

세그먼트 맨 앞 128바이트는 헤더다. 헤더 없는 세그먼트는 만들지 않는다.

| 필드 | 뜻 | 검증 실패 시 |
|---|---|---|
| `magic` | 세그먼트 종류. **초기화가 끝난 뒤 마지막에 쓴다** | 0이면 초기화 중(`-EAGAIN`), 다르면 `-EBADMSG` |
| `layout_ver` | 레코드 레이아웃 버전(`c-data-structures` 헤더의 버전) | `-EPROTO` — 다른 버전의 프로그램 |
| `rec_size`·`rec_cap` | 레코드 크기·최대 건수 | `-EPROTO`·`-EINVAL` |
| `rec_cnt` | 현재 건수. 락 안에서만 바꾼다 | 용량 초과면 `-EINVAL` |
| `state` | `INIT`·`READY`·`RECOVERING`·`CORRUPT` | `CORRUPT`면 `-EIO` |
| `created_ts` | 생성 시각 | 재기동 판단·진단용 |
| `load_seq` | 마지막 DB 적재·반영 시퀀스(체크포인트) | DB 대조 기준 |
| `checksum` | 레코드 영역 체크섬 | 정합성 검사·복구 판정 |
| `lock` | 프로세스 공유 뮤텍스(고정 64바이트 영역) | — |

`shm_segment.c` 발췌 — 생성자는 매직을 맨 마지막에 쓴다:

```c
    hdr->layout_ver = layout->layout_ver;
    hdr->rec_size   = layout->rec_size;
    hdr->rec_cap    = layout->rec_cap;
    hdr->created_ts = (int64_t)time(NULL);
    atomic_store(&hdr->state, SHM_STATE_INIT);
    ret = ShmLockInit(&hdr->lock.mutex);
    /* ... 실패 처리 ... */
    /* release — 앞의 헤더 초기화가 매직보다 먼저 보이게 한다 */
    atomic_store_explicit(&hdr->magic, SHM_MAGIC, memory_order_release);
```

- 매직은 `_Atomic` 필드다. attach 쪽은 acquire로 읽으므로, 매직이 보이면 나머지 헤더도 보인다.

`ShmSegAttach`는 매핑한 뒤 `ShmHdrCheck`를 통과해야만 핸들을 돌려준다. 실패하면 매핑을 풀고 실패한다.
조회 도구는 `SHM_ATTACH_RDONLY`로, 복구 도구는 `SHM_ATTACH_ALLOW_CORRUPT`로 attach한다.

### 상태 전환

상태는 원자적 compare-and-swap으로만 바꾼다. 허용된 전이 밖은 `-EINVAL`이다.

```text
INIT ──적재 완료──▶ READY ──재적재 시작──▶ RECOVERING ──완료──▶ READY
  └──────────────┬─────────────────────────────┘
                 ▼
              CORRUPT ──복구 시작──▶ RECOVERING
```

- 조회는 `READY`에서만 한다. 다른 상태면 "준비 안 됨"을 돌려주고, 호출자가 재시도하거나 DB로 우회한다.
- `CORRUPT`에서 `READY`로 바로 가지 않는다. 반드시 `RECOVERING`을 거쳐 재적재·검증한다.

## 동시성 — 방식 하나를 고르고 문서화한다

| 기준 | robust 프로세스 공유 뮤텍스 | 단일 작성자 + 시퀀스 락 |
|---|---|---|
| 작성자 | 여러 프로세스 | 한 프로세스(한 스레드) |
| 독자 | 적거나 락 대기를 견딘다 | 많고 지연에 민감하다 |
| 독자 비용 | 락 획득 | 락 없음. 쓰기와 겹치면 다시 읽는다 |
| 작성자 사망 | `EOWNERDEAD`로 감지·복구 | 시퀀스가 홀수로 멈춘다 → 감시로 감지 |
| 이식성 | robust 속성은 리눅스(glibc) 전용 | C11 원자 연산만 쓴다 |

- 작성자가 여럿이면 robust 뮤텍스다. 락 없는 다중 작성은 금지다.
- 읽기가 압도적이고 작성자를 하나로 만들 수 있으면 시퀀스 락을 고른다. 이 편이 단순하고 빠르다.
- 고른 방식과 락 획득 순서를 모듈 헤더 주석에 적는다(철학 11절 "공유 가변 상태 허용 조건").

### 락 범위 최소화

- 락 안에서는 레코드 복사·변경만 한다. DB 호출·파일 I/O·로그 출력·콜백은 락 밖에서 한다.
- DB 반영은 락 안에서 변경분을 지역 버퍼로 복사하고, 락을 푼 뒤 DB에 쓴다.
- 여러 세그먼트의 락을 함께 잡아야 하면 이름 순서 같은 고정 순서를 정하고 문서화한다.

### robust 뮤텍스와 `EOWNERDEAD`

뮤텍스는 `PTHREAD_PROCESS_SHARED`와 `PTHREAD_MUTEX_ROBUST`로 초기화한다.
락을 쥔 프로세스가 죽으면 다음 `pthread_mutex_lock`이 `EOWNERDEAD`를 반환한다. 이때 락은 이미 잡힌 상태다.

1. 보호 대상(레코드 영역·건수)을 검증한다. 정렬 불변식·건수 범위·필드 범위를 본다.
2. 복구할 수 있으면 고치고 `pthread_mutex_consistent`를 호출한다. 이후 락은 정상으로 돌아온다.
3. 복구할 수 없으면 상태를 `CORRUPT`로 바꾸고 consistent 없이 푼다. 이후 락은 `ENOTRECOVERABLE`이다. DB에서 다시 적재한다.

`shm_segment.c` 발췌 — 복구 판단은 함수 포인터로 주입한다:

```c
    rc = pthread_mutex_lock(&seg->hdr->lock.mutex);
    if (rc == 0)
    {
        return 0;
    }
#ifdef __linux__
    if (rc == EOWNERDEAD)
    {
        if (repair_fn != NULL && repair_fn(seg, ctx) == 0)
        {
            rc = pthread_mutex_consistent(&seg->hdr->lock.mutex);
            if (rc == 0)
            {
                return SHM_LOCK_RECOVERED;
            }
        }
        atomic_store(&seg->hdr->state, SHM_STATE_CORRUPT);
        pthread_mutex_unlock(&seg->hdr->lock.mutex);
        return -ENOTRECOVERABLE;
    }
#endif
    return -rc;
```

- 복구 콜백의 예: `ItemTableCheckSorted`가 0이고 건수가 용량 이하면 0을 돌려준다. 더티 플래그는 그대로 두어 DB 반영이 이어지게 한다.
- macOS에는 robust 속성이 없다. 예제는 `#ifdef __linux__`로 감싸고, macOS에서는 일반 프로세스 공유 뮤텍스로 빌드만 확인한다.
  `EOWNERDEAD` 테스트 2개는 리눅스에서만 돈다(`test_shm_segment.c`).

### 단일 작성자 + 시퀀스 락

헤더 예약 영역에 `_Atomic uint64_t write_seq`를 두는 방식이다. 필드를 추가하면 레이아웃 버전을 올린다.
메모리 오더링은 기본값(`seq_cst`)에서 시작한다. 약화하려면 근거를 주석으로 남긴다.

```c
/* 작성자(하나뿐) — 홀수는 쓰는 중, 짝수는 완료 */
atomic_fetch_add(&hdr->write_seq, 1);
tbl.recs[idx].prc = new_prc;
atomic_fetch_add(&hdr->write_seq, 1);

/* 독자 — 쓰기와 겹쳤으면 다시 읽는다 */
for (;;)
{
    uint64_t seq_begin = atomic_load(&hdr->write_seq);

    if ((seq_begin & 1u) != 0)
    {
        continue;                               /* 쓰는 중 */
    }
    memcpy(&out_rec, &tbl.recs[idx], sizeof(out_rec));
    atomic_thread_fence(memory_order_acquire);
    if (atomic_load(&hdr->write_seq) == seq_begin)
    {
        break;
    }
}
```

- 독자는 복사본만 쓴다. 공유메모리 레코드를 가리키는 포인터를 들고 있지 않는다.
- 시퀀스가 오래 홀수로 멈춰 있으면 작성자가 죽은 것이다. 감시 프로세스가 `CORRUPT`로 표시하고 재적재한다.
- 겹친 복사는 C11 기준으로 데이터 경쟁이다. 실무 관용구지만, 엄격히 하려면 필드를 원자 변수로 읽는다.

## DB → 공유메모리 적재

기동 적재는 다음 순서다. 공유메모리에는 검증이 끝난 데이터만 들어간다.

1. 소유 프로세스가 세그먼트를 만든다(상태 `INIT`). 독자는 `READY`가 아니므로 조회하지 않는다.
2. Pro*C 호스트 배열 fetch로 프로세스 지역 임시 영역(staging)에 전량을 읽는다.
3. 임시 영역에서 정렬하고 검증한다(`ItemTableBulkLoad`: `qsort` → 중복 검사).
4. 락을 잡고 세그먼트로 복사한다. 건수·`load_seq`·체크섬을 기록하고 락을 푼다.
5. `INIT → READY`로 원자 전환한다. 이 순간부터 독자가 조회한다.

호스트 배열 fetch 골격(Pro*C, 한 번에 `FETCH_ROWS`건):

```c
EXEC SQL BEGIN DECLARE SECTION;
    unsigned int h_item_id[FETCH_ROWS];
    unsigned int h_group_id[FETCH_ROWS];
    long         h_prc[FETCH_ROWS];
    long         h_qty[FETCH_ROWS];
EXEC SQL END DECLARE SECTION;

EXEC SQL DECLARE item_cur CURSOR FOR
    SELECT item_id, group_id, prc, qty FROM item_master ORDER BY item_id;
EXEC SQL OPEN item_cur;
for (;;)
{
    EXEC SQL FETCH item_cur INTO :h_item_id, :h_group_id, :h_prc, :h_qty;
    if (sqlca.sqlcode < 0)
    {
        goto fail;                                  /* 맥락을 붙여 한 번만 기록 */
    }
    fetched = sqlca.sqlerrd[2] - total;             /* Pro*C 는 누적 건수 */
    CopyToStaging(staging, total, h_item_id, h_group_id, h_prc, h_qty, fetched);
    total += fetched;
    if (sqlca.sqlcode == 1403)
    {
        break;                                      /* 마지막 부분 묶음까지 처리 */
    }
}
EXEC SQL CLOSE item_cur;
```

- `ORDER BY`가 있어도 `BulkLoad`의 정렬·중복 검사를 생략하지 않는다. DB와 C의 비교 규칙이 다를 수 있다.
- NULL 가능 컬럼은 인디케이터 배열을 함께 받는다. ecpg의 누적 건수 의미는 `embedded-sql` 차이표로 확인한다.
- 대용량 fetch의 배열 크기·멀티스레드 컨텍스트는 `embedded-sql`의 호스트 배열 절을 따른다.

### 운영 중 재적재

- 독자가 잠깐 멈춰도 되면 `READY → RECOVERING`으로 바꾸고 같은 절차로 다시 채운 뒤 `READY`로 돌린다.
- 독자가 멈추면 안 되면 같은 크기의 영역 두 벌을 두고, 헤더의 활성 영역 번호를 원자적으로 바꾼다.
- 어느 쪽이든 임시 영역 검증이 끝나기 전에는 공유메모리를 건드리지 않는다.

## 공유메모리 → DB 반영

| 방식 | 언제 | 특징 |
|---|---|---|
| 더티 플래그(`ITEM_FLAG_DIRTY`) | 마지막 값만 중요하다(현재 상태 테이블) | 같은 레코드의 여러 변경이 한 번에 합쳐진다 |
| 변경 큐(링버퍼) | 변경 이력·순서가 중요하다, 삽입·삭제가 있다 | 큐가 차면 반영 지연을 경보한다 |

주기 배치 반영 순서:

1. 락을 잡고 더티 레코드를 지역 버퍼로 복사한다. 각 레코드의 `last_ts`도 함께 기억한다. 락을 푼다.
2. 호스트 배열 update를 한 번에 보낸다. 예: `EXEC SQL FOR :n UPDATE item_master SET prc = :h_prc, qty = :h_qty WHERE item_id = :h_item_id;`
3. 성공하면 `COMMIT`한다. 락을 잡고, `last_ts`가 그대로인 레코드만 더티를 지운다. 체크포인트 시퀀스(`load_seq`)를 올린다.
4. 실패하면 `ROLLBACK`한다. 더티 플래그는 그대로 두고 지수 백오프로 재시도한다.
5. 정해진 횟수를 넘으면 반영을 보류하고 경보한다. 변경분은 버리지 않는다.

- 반영 중에 바뀐 레코드는 `last_ts`가 달라서 더티가 남는다. 다음 주기에 다시 반영된다.
- 반영 건수(`sqlca.sqlerrd[2]`)가 보낸 건수와 다르면 DB에 없는 키가 있다는 뜻이다. 보고 대상이다.

## 정합성 대조

공유메모리와 DB가 같은지 주기적으로, 그리고 복구 직후 반드시 확인한다.

| 검사 | 방법 | 비용 |
|---|---|---|
| 건수 | `rec_cnt` vs `SELECT COUNT(*)` | 낮음 |
| 체크섬 | DB 행을 같은 변환으로 레코드화해 체크섬 비교 | 높음(전량) |
| 표본 | 무작위 N개 키의 필드 값 비교 | 중간 |
| 불변식 | `CheckSorted`·`ShmSegVerifyChecksum` | 낮음(메모리만) |

- 대조는 더티 레코드를 제외하고 한다. 반영 대기 중인 값은 원래 다르다.
- 불일치는 키와 필드 이름만 보고한다. 개인정보 필드 값은 보고에 넣지 않는다.
- 불일치를 조용히 고치지 않는다. 보고하고 런북 절차로 판단한다.

## 금지 사항

- 공유메모리에 포인터를 저장한다 — 프로세스마다 주소가 다르다. 인덱스·오프셋·키를 쓴다.
- 헤더 검증 없이 attach한다 — 다른 버전·초기화 중·손상 세그먼트를 그대로 쓰게 된다.
- 락 없이 여러 프로세스가 쓴다 — robust 뮤텍스 또는 단일 작성자 중 하나를 고른다.
- 조회에 쓰지 않는 개인정보 필드를 적재한다 — 공유메모리는 권한만 있으면 누구나 덤프할 수 있다.
- 락을 쥔 채 DB·파일 I/O나 로그 출력을 한다.
- `CORRUPT`를 `READY`로 직접 바꾼다.

## 수명과 권한

- **소유 프로세스 하나**가 생성·적재·삭제를 맡는다(보통 마스터 또는 로더). 워커는 attach·detach만 한다.
- 워커는 종료할 때 detach한다. 세그먼트 삭제는 소유 프로세스 종료 절차나 운영 도구만 한다.
- 권한은 최소로 준다. 같은 계정만 쓰면 `0600`, 조회 도구 그룹이 읽어야 하면 `0640`이다. `umask`도 함께 맞춘다.
- 이름에는 서비스 이름을 붙인다. 예: `/ordsvc_item`. 운영 환경과 테스트 환경의 이름을 섞지 않는다.

재기동 시 재사용과 재생성 규칙:

| 기존 세그먼트 상태 | 조치 |
|---|---|
| 헤더 검증 통과, `READY`, 체크섬 일치 | 재사용한다(빠른 재기동). 더티 레코드 반영부터 재개한다 |
| 레이아웃 버전·레코드 크기 불일치 | 삭제하고 다시 만든 뒤 DB에서 적재한다 |
| `INIT`·`RECOVERING`으로 남음 | 이전 적재가 중간에 죽었다. 삭제하고 다시 만든다 |
| `CORRUPT`·체크섬 불일치 | 재적재 전에 더티 레코드를 확인한다. 반영할 수 없으면 손실 범위를 기록한다 |

## 운영 — 복구 런북 템플릿

장애 대응은 **증상 → 판정 → 조치 → 검증 → 기록** 순서로 쓴다. 프로젝트는 세그먼트마다 이 표를 채운다.
운영 도구 `shmctl.sh`·`shm_recover`·`shm_view`는 W4에서 `templates/project/profiles/c-system/tools/`에 들어온다.
도구가 들어오기 전에는 `ipcs -m`·`ls -l /dev/shm`·예제의 검증 함수로 같은 판단을 한다.

| 단계 | 할 일 | 도구 예 |
|---|---|---|
| 증상 | 조회 실패(`-EIO`·`-EAGAIN`), `ENOTRECOVERABLE` 로그, 대조 불일치, 시퀀스 멈춤 | 서비스 로그 |
| 판정 | 헤더 요약(매직·버전·상태·건수·`load_seq`)과 attach 프로세스 수를 본다 | `shmctl.sh status <이름>`, `shm_view --header` |
| 판정 | 손상 여부를 확정한다(매직·버전·체크섬·상태 플래그·정렬 불변식) | `shm_recover --verify-only` |
| 조치 | 먼저 영향 없이 확인한다. 그다음 DB에서 재적재한다 | `shm_recover --dry-run` → `shm_recover` |
| 조치 | 다시 만들어야 하면 소유 프로세스를 멈춘 뒤 삭제한다 | `shmctl.sh remove <이름>`(확인 프롬프트) |
| 검증 | 상태 `READY`, 건수·체크섬·표본 대조 통과, 서비스 조회 정상 | `shm_view`, 정합성 대조 |
| 기록 | 시각·증상·판정 근거·조치 명령·결과·손실 범위(미반영 더티 건수) | 장애 기록 |

예: 워커가 락을 쥔 채 죽은 경우.

1. 증상 — 다른 워커 로그에 `EOWNERDEAD` 복구 실패와 `ENOTRECOVERABLE`이 찍힌다.
2. 판정 — 헤더 상태가 `CORRUPT`다. `--verify-only`가 정렬 불변식 위반을 보고한다.
3. 조치 — 미반영 더티 건수를 기록하고, `shm_recover`로 `CORRUPT → RECOVERING → READY` 재적재를 한다.
4. 검증 — 건수와 체크섬이 DB와 맞고, 워커 조회가 정상으로 돌아온다.
5. 기록 — 손실된 변경 건수와 원인 프로세스를 남긴다. 재현 테스트를 추가한다.

- 운영 서버에서는 읽기 전용 조회부터 한다. 쓰기 조치 전에는 영향 범위를 확인받는다.
- 출력에서 개인정보 필드는 기본 마스킹한다(`shm_view` 기본값).

## 점검 목록

- [ ] POSIX·SysV 중 하나를 골랐고, 이름·권한·삭제 책임자를 적었다
- [ ] 헤더에 매직·버전·크기·건수·상태·시퀀스·체크섬이 있고 attach마다 검증한다
- [ ] 동기화 방식(robust 뮤텍스 또는 단일 작성자 + 시퀀스 락)과 락 순서를 문서화했다
- [ ] `EOWNERDEAD` 경로가 검증·복구 후 consistent, 실패 시 `CORRUPT`로 간다
- [ ] 락 안에서 I/O·로그를 하지 않는다
- [ ] 적재는 임시 영역 → 검증 → 상태 전환 순서다
- [ ] 반영 실패 시 변경분을 버리지 않고 재시도·보류한다
- [ ] 정합성 대조와 복구 런북이 있다
- [ ] 동시성 코드는 TSan과 리눅스 `EOWNERDEAD` 테스트로 검증했다

## 참조

- 예제: `templates/project/c-system/src/shm/shm_segment.h`·`shm_segment.c`·`test_shm_segment.c`, `make test`
- 레코드·정렬·조회: `c-data-structures`
- 철학: `rules/systems/philosophy.md` 11절 "공유 가변 상태 허용 조건", `rules/systems/decisions.md` D12
- 임베디드 SQL: `embedded-sql` · 개인정보: `sensitive-data-handling` · 메모리 검사: `memory-check`
