---
name: c-data-structures
description: C 서버의 수신 데이터 저장소를 자료구조와 정렬로 찾기 쉽고 고치기 쉽게 만드는 규약. 접근 패턴별 선택표(정확 일치 → 개방 주소법 해시, 범위·순서 → 키 정렬 배열 + bsearch, 최근 N건 → 링버퍼, 다중 키 → 주 배열 + 보조 인덱스 배열), 정렬 유지 전략(memmove 삽입 vs 일괄 적재 후 qsort), 고정 크기 레코드 설계(키 필드 앞·명시 패딩·_Static_assert·포인터 대신 인덱스), 비교 함수 규약, 조회 API 이름·반환 규약 통일, CheckSorted 불변식 검사, 레이아웃 버전 관리. 대상 경로 — **/*.c, **/*.h, **/*.pc, **/*.pgc. 키워드 — 자료구조 선택, 정렬 배열, bsearch, qsort, 해시 테이블, 링버퍼, 보조 인덱스, 고정 크기 레코드, 비교 함수, CheckSorted.
---

# C 자료구조 — 정렬과 고정 레코드로 찾기 쉬운 저장소

데이터는 **고정 크기 레코드의 연속 배열**에 두고, 접근 패턴에 맞는 순서나 색인을 붙인다.
연결 리스트와 트리는 측정 근거가 있을 때만 쓴다(`rules/systems/decisions.md` D07).
같은 저장소는 같은 함수 이름과 같은 반환 규약으로 조회한다.
이 규칙을 지키면 공유메모리에 그대로 올릴 수 있고, 조회 도구도 같은 함수를 재사용한다.

동작하는 예제는 `templates/project/c-system/src/shm/`에 있다.
`sorted_table.h`·`sorted_table.c`가 이 스킬의 기준 구현이고, `make test`로 검증한다.

## 언제 사용하나

- 수신 데이터(시세·주문·상태 등)를 메모리에 모아 두고 키로 찾아야 할 때
- 공유메모리에 올릴 레코드 구조체를 새로 정의하거나 필드를 바꿀 때
- 조회 함수 이름이 `Get`·`Search`·`Lookup`으로 섞여 있어 정리할 때
- 정렬 상태가 깨졌다는 의심이 들어 불변식 검사를 넣을 때

### 언제 사용하지 않나

- 공유메모리 생성·락·DB 적재 절차 → `shm-db-patterns`
- C++ 코드 → 표준 컨테이너를 먼저 쓴다(`cpp-patterns`)
- 스레드 간 메시지 전달 큐의 동기화 세부 → `latency-critical-systems`

## 선택표 — 접근 패턴이 자료구조를 정한다

먼저 "어떻게 찾는가"를 적는다. 자료구조는 그 답에서 나온다.

| 접근 패턴 | 자료구조 | 조회 비용 | 비고 |
|---|---|---|---|
| 키 하나로 정확히 찾기만 한다 | 개방 주소법 해시(선형 탐사) | 평균 O(1) | 순서 조회가 필요 없을 때만 |
| 범위·순서 조회가 있다 | **키 정렬 배열 + `bsearch`** | O(log n) | 기본 선택. 순회도 정렬 순서 |
| 최근 N건·시계열만 본다 | 링버퍼(고정 용량, 오래된 것부터 덮어씀) | O(1) 추가 | 시각 범위는 정렬된 시각으로 이분 탐색 |
| 키가 둘 이상이다 | 주 배열 + 보조 인덱스 배열 | O(log n) | 보조 인덱스는 주 키를 담는다 |

- 망설여지면 **키 정렬 배열**을 고른다. 범위 조회·순회·덤프·대조가 모두 쉽다.
- 해시는 순서가 없어서 범위 조회와 정렬 출력이 불가능하다. 정확 일치만 있을 때 쓴다.
- 레코드 수가 수십 건 이하면 선형 탐색도 충분하다. 측정 전에 복잡하게 만들지 않는다.

### 정렬 유지 전략 — 삽입 빈도로 고른다

| 상황 | 전략 | 비용 |
|---|---|---|
| 기동 시 전량 적재, 이후 갱신이 대부분 | 버퍼에 모두 넣고 `qsort` 한 번 | O(n log n) 한 번 |
| 운영 중 가끔 삽입·삭제 | 위치를 찾아 `memmove`로 밀고 넣기 | 건당 O(n) 이동 |
| 운영 중 삽입이 매우 잦다 | 작은 버퍼에 모았다가 주기적으로 병합 | 측정 후 결정 |

- 64바이트 레코드 10만 건의 `memmove`는 수 MB 이동이다. 초당 삽입 수와 곱해 보고 판단한다.
- 갱신(키가 같은 레코드의 값 변경)은 순서를 바꾸지 않는다. 찾아서 제자리에서 고친다.

## 고정 크기 레코드 설계

레코드는 공유메모리·파일·네트워크에 그대로 놓일 수 있게 만든다.

1. **크기를 고정한다.** 가변 길이 문자열은 고정 길이 `char` 배열로 둔다.
2. **키 필드를 맨 앞에 둔다.** 덤프를 눈으로 볼 때 키가 먼저 보이고, 비교가 앞쪽 캐시라인에서 끝난다.
3. **패딩을 명시 필드로 적는다.** 컴파일러가 넣는 숨은 패딩에 기대지 않는다. 큰 필드부터 놓는다.
4. **`_Static_assert`로 크기를 고정한다.** 필드를 바꾸면 빌드가 깨져서 버전 증가를 잊지 않는다.
5. **포인터를 두지 않는다.** 다른 레코드는 배열 인덱스나 키로 가리킨다. 프로세스마다 주소가 다르다.
6. **개인정보는 필요한 필드만 둔다.** 조회에 쓰지 않는 개인정보는 레코드에 넣지 않는다(`sensitive-data-handling`).

`templates/project/c-system/src/shm/sorted_table.h` 발췌:

```c
#define ITEM_LAYOUT_VER   1u
#define ITEM_NAME_LEN     16u

typedef struct ItemRec
{
    uint32_t item_id;               /* 주 키 — 테이블 정렬 기준 */
    uint32_t group_id;              /* 보조 키 — 보조 인덱스 후보 */
    int64_t  prc;                   /* 가격(최소 호가 단위 정수) */
    int64_t  qty;                   /* 수량 */
    int64_t  last_ts;               /* 마지막 갱신 시각(에포크 마이크로초) */
    char     name[ITEM_NAME_LEN];   /* 표시 이름(NUL 종료 보장 안 함) */
    uint32_t flags;                 /* 상태 비트 — ITEM_FLAG_* */
    uint8_t  reserved[12];          /* 명시 패딩 — 0 으로 둔다 */
} ItemRec;

_Static_assert(sizeof(ItemRec) == 64, "ItemRec 크기가 바뀌면 ITEM_LAYOUT_VER 를 올린다");
_Static_assert(offsetof(ItemRec, item_id) == 0, "주 키는 레코드 맨 앞에 둔다");
```

- 가격·금액은 부동소수가 아니라 최소 단위 정수로 둔다. 비교와 합계가 정확해진다.
- 64바이트(캐시라인 하나)에 맞추면 레코드 하나를 읽을 때 캐시라인 하나만 건드린다.
- 예약 필드(`reserved`)를 두면 필드를 추가해도 크기가 그대로다. 그래도 의미가 바뀌면 버전은 올린다.

## 비교 함수 규약

- **키 하나에 비교 함수 하나.** 이름은 `<레코드>CmpBy<키>`로 짓는다. 예: `ItemCmpById`.
- 서명은 `qsort`·`bsearch`와 같은 `int (*)(const void *, const void *)`로 맞춘다.
- 뺄셈으로 비교하지 않는다. `a - b`는 넘친다. `(a > b) - (a < b)`를 쓴다.
- **다중 키 비교 순서는 함수 위 주석에 적는다.** 앞 키가 같을 때만 다음 키를 본다.
- 마지막 키는 주 키로 끝낸다. 그러면 모든 레코드의 순서가 하나로 정해진다.

```c
/* 다중 키: group_id 오름차순 → item_id 오름차순 (보조 인덱스 정렬용) */
int ItemCmpByGroupId(const void *lhs, const void *rhs)
{
    const ItemRec *left  = lhs;
    const ItemRec *right = rhs;

    if (left->group_id != right->group_id)
    {
        return (left->group_id > right->group_id) ? 1 : -1;
    }
    return ItemCmpById(lhs, rhs);
}
```

### 안정성

- `qsort`는 안정 정렬이 아니다. 같은 키의 원래 순서가 보존되지 않는다.
- 키가 유일하면 안정성은 문제가 되지 않는다. 결과가 하나로 정해지기 때문이다.
- 키가 겹칠 수 있으면 비교 함수 끝에 주 키나 적재 순번을 더해 순서를 하나로 만든다.

## 조회 API — 이름과 반환 규약 통일

저장소마다 같은 동사를 쓴다. 동사는 `naming-dictionary`의 사전과 맞춘다.

| 함수 | 역할 | 성공 반환 | 실패 반환 |
|---|---|---|---|
| `<Domain>Find` | 정확 일치 조회 | 인덱스(0 이상) | `-ENOENT` |
| `<Domain>FindRange` | 하한·상한(양끝 포함) 구간 | 구간 건수, 첫 인덱스는 출력 인자 | `-EINVAL`(하한 > 상한) |
| `<Domain>Insert` | 순서를 유지하며 삽입 | 삽입 위치 인덱스 | `-EEXIST`·`-ENOSPC` |
| `<Domain>Remove` | 삭제 후 뒤를 당김 | 0 | `-ENOENT` |
| `<Domain>CheckSorted` | 정렬 불변식 검사 | 0 | `-EILSEQ` |

- **반환 규약은 하나다.** 0 이상은 성공(인덱스·건수), 음수는 `-errno`다. 포인터·`-1`·`bool`을 섞지 않는다.
- 같은 뜻으로 `Get`·`Search`·`Lookup`을 쓰지 않는다.
- 인덱스는 다음 삽입·삭제 전까지만 유효하다. 오래 들고 있어야 하면 키를 들고 있는다.

`sorted_table.c` 발췌 — 정확 일치는 `bsearch`, 구간은 하한 탐색 두 번이다:

```c
int ItemTableFind(const ItemTable *tbl, uint32_t item_id)
{
    ItemRec        key   = { .item_id = item_id };
    const ItemRec *found = NULL;

    found = bsearch(&key, tbl->recs, *tbl->cnt_ptr, sizeof(ItemRec), ItemCmpById);
    if (found == NULL)
    {
        return -ENOENT;
    }
    return (int)(found - tbl->recs);
}

int ItemTableFindRange(const ItemTable *tbl, uint32_t lo_id, uint32_t hi_id,
                       uint32_t *out_first)
{
    /* ... 인자 검사 ... */
    first = ItemTableLowerBound(tbl, lo_id);
    /* hi_id + 1 이 넘치는 경우(UINT32_MAX)는 끝까지가 구간이다 */
    last  = (hi_id == UINT32_MAX) ? *tbl->cnt_ptr : ItemTableLowerBound(tbl, hi_id + 1);
    *out_first = first;
    return (int)(last - first);
}
```

정렬 유지 삽입 발췌 — 위치를 찾고, 중복과 용량을 검사하고, 민다:

```c
    pos = ItemTableLowerBound(tbl, rec->item_id);
    if (pos < cnt && tbl->recs[pos].item_id == rec->item_id)
    {
        return -EEXIST;
    }
    if (cnt >= tbl->cap)
    {
        return -ENOSPC;
    }
    memmove(&tbl->recs[pos + 1], &tbl->recs[pos], (size_t)(cnt - pos) * sizeof(ItemRec));
    tbl->recs[pos] = *rec;
    *tbl->cnt_ptr  = cnt + 1;

    assert(ItemTableCheckSorted(tbl) == 0);     /* 디버그 빌드 불변식 */
    return (int)pos;
```

### 테이블 뷰 — 저장 공간과 분리한다

`ItemTable`은 프로세스 지역 뷰다. 레코드 배열과 건수가 어디 있는지만 가리킨다.
배열과 건수는 공유메모리에 둘 수 있지만, 뷰 자체는 공유메모리에 두지 않는다.
이렇게 나누면 같은 조회 코드가 지역 배열·공유메모리·읽기 전용 조회 도구에서 모두 돈다.

```c
ItemTable tbl;

ItemTableBind(&tbl, ShmSegData(seg), &ShmSegHdr(seg)->rec_cnt, ShmSegHdr(seg)->rec_cap);
```

## 다른 구조의 핵심 규칙

### 개방 주소법 해시

- 용량은 2의 거듭제곱으로 잡고, 적재율은 0.7 이하로 유지한다.
- 슬롯에는 레코드 대신 **레코드 인덱스**를 담는다. 빈 슬롯과 삭제 표시(tombstone)는 음수로 구분한다.
- 삭제는 tombstone으로 표시한다. 바로 비우면 그 뒤의 탐사 사슬이 끊긴다.
- tombstone이 쌓이면 전체를 다시 만든다(rehash). 시점은 tombstone 비율로 정한다.
- 아래는 골격이다. 공유메모리에 둘 때는 슬롯 배열도 세그먼트 안의 오프셋으로 찾는다.

```c
#define HASH_SLOT_EMPTY  (-1)
#define HASH_SLOT_TOMB   (-2)

/* 정확 일치 조회 — 빈 슬롯을 만나면 없는 키다 */
int ItemHashFind(const ItemHash *hash, const ItemRec *recs, uint32_t item_id)
{
    uint32_t mask = hash->cap - 1;
    uint32_t pos  = ItemIdHash(item_id) & mask;
    uint32_t ii   = 0;

    for (ii = 0; ii < hash->cap; ii++)
    {
        int32_t slot = hash->slots[(pos + ii) & mask];

        if (slot == HASH_SLOT_EMPTY)
        {
            return -ENOENT;
        }
        if (slot >= 0 && recs[slot].item_id == item_id)
        {
            return slot;
        }
    }
    return -ENOENT;
}
```

### 링버퍼 — 최근 N건

- 용량은 2의 거듭제곱이다. 위치는 `seq & (cap - 1)`로 구한다.
- 쓰기 순번(`write_seq`)은 줄지 않는 64비트 정수다. 넘침을 걱정하지 않아도 된다.
- 가장 오래된 유효 순번은 `write_seq - cap`(음수면 0)이다. 그보다 오래된 것은 덮어써졌다.
- 스레드 간에 쓰면 단일 생산자-단일 소비자로 한정하고 acquire/release 오더링을 쓴다
  (`rules/systems/philosophy.md` 11절).

### 다중 키 — 주 배열 + 보조 인덱스 배열

- 레코드 본문은 주 키로 정렬한 주 배열 하나에만 둔다. 복사본을 만들지 않는다.
- 보조 인덱스는 `{보조 키, 주 키}` 쌍의 정렬 배열이다. 정렬은 보조 키 → 주 키 순서다.
- 보조 인덱스에 **주 배열 인덱스를 담지 않는다.** 주 배열에 삽입하면 인덱스가 모두 밀린다.
- 조회는 두 단계다. 보조 인덱스에서 주 키를 찾고, 주 배열에서 `<Domain>Find`로 찾는다.
- 주 배열을 바꾸는 함수가 보조 인덱스도 함께 고친다. 호출자가 따로 고치게 하지 않는다.

```c
typedef struct ItemGroupIdx
{
    uint32_t group_id;  /* 보조 키 */
    uint32_t item_id;   /* 주 키 — 주 배열 인덱스가 아니다 */
} ItemGroupIdx;
```

## 정렬 불변식 검사 — `<Domain>CheckSorted`

정렬이 깨지면 `bsearch`는 조용히 틀린 답을 준다. 그래서 불변식을 검사하는 함수를 따로 둔다.

```c
int ItemTableCheckSorted(const ItemTable *tbl)
{
    uint32_t ii = 0;

    if (*tbl->cnt_ptr > tbl->cap)
    {
        return -EILSEQ;
    }
    for (ii = 1; ii < *tbl->cnt_ptr; ii++)
    {
        if (tbl->recs[ii - 1].item_id >= tbl->recs[ii].item_id)
        {
            return -EILSEQ;     /* 순서 위반 또는 중복 키 */
        }
    }
    return 0;
}
```

- 변경 함수 끝에서 `assert(<Domain>CheckSorted(tbl) == 0)`으로 부른다. 운영 빌드(`NDEBUG`)에서는 빠진다.
- 디버그 빌드에서는 삽입마다 O(n) 검사가 돈다. 대량 성능 측정은 `NDEBUG` 빌드로 한다.
- 운영에서는 적재 직후, 복구 직후, 조회 도구의 검증 명령에서 명시적으로 부른다.
- 건수가 용량을 넘는 것도 손상이다. 순서 검사 전에 먼저 본다.

## 유지보수

- **레이아웃과 키 정의는 헤더 하나에 둔다.** 레코드 구조체, 키 설명, 비교 함수 선언, 레이아웃 버전이 한 파일에 있다.
- **필드를 바꾸면 레이아웃 버전을 올린다.** 공유메모리 헤더가 이 버전을 담는다. 버전이 다른 프로세스는 attach에서 거부된다(`shm-db-patterns`).
- **단위 테스트는 불변식과 경계 키를 본다.** 빈 테이블, 키 0, 키 최댓값, 가득 찬 테이블, 중복 키, 맨 앞·맨 뒤 삭제, 빈 구간.
- 정렬을 일부러 깨뜨려 `CheckSorted`가 잡는지도 테스트한다.
- 새 약어(`Prc`·`Qty` 등)는 프로젝트 사전에 있는 것만 쓴다(`naming-dictionary`).

`test_sorted_table.c`가 다루는 경우:

| 테스트 | 확인하는 것 |
|---|---|
| `TestFindOnEmptyReturnsEnoent` | 빈 테이블 조회·전 구간 조회 |
| `TestInsertOutOfOrderKeepsSorted` | 무작위 순서 삽입 후 정렬 유지 |
| `TestBoundaryKeysFound` | 키 0·`UINT32_MAX`, 상한 넘침 방지 |
| `TestDuplicateAndFullRejected` | `-EEXIST`·`-ENOSPC` |
| `TestRemoveShiftsRecords` | 맨 앞·맨 뒤 삭제, 없는 키 |
| `TestFindRangeInclusiveBounds` | 양끝 포함, 빈 구간, 앞·뒤 밖, 하한 > 상한 |
| `TestBulkLoadSortsAndRejectsDuplicate` | 일괄 적재 정렬, 중복 시 적재 취소 |
| `TestCheckSortedDetectsCorruption` | 순서 위반·건수 초과 탐지 |

## 점검 목록

- [ ] 접근 패턴을 먼저 적고 선택표로 자료구조를 골랐다
- [ ] 레코드는 고정 크기이고 `_Static_assert`로 크기를 고정했다
- [ ] 키 필드가 맨 앞이고 패딩이 명시 필드다
- [ ] 레코드에 포인터가 없다
- [ ] 비교 함수는 뺄셈을 쓰지 않고, 다중 키 순서를 주석에 적었다
- [ ] 조회 함수 이름과 반환 규약이 저장소 전체에서 같다
- [ ] 변경 함수 끝에 `CheckSorted` 단언이 있다
- [ ] 레이아웃을 바꿨으면 버전을 올렸다
- [ ] 경계 키와 불변식 위반을 테스트했다

## 참조

- 예제: `templates/project/c-system/src/shm/sorted_table.h`·`sorted_table.c`·`test_sorted_table.c`
- 공유메모리 적재·락·헤더: `shm-db-patterns`
- 철학: `rules/systems/philosophy.md` 3절(자료구조)·9절(이식성)·11절(동시성)
- 이름 규칙: `naming-dictionary`, `rules/c/coding-style.md`
- 테스트 실행: `c-testing`, `memory-check`
