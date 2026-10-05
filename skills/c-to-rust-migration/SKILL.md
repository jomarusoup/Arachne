---
name: c-to-rust-migration
description: 불투명 핸들·함수 포인터 ops 테이블로 짠 C 서버를 Rust로 옮길 수 있는지 판단하고 옮기는 지침. 대응표(핸들 → 비공개 필드 구조체+impl, ops 테이블 → trait 정적·동적 디스패치, goto 정리 → Drop, errno → Result·thiserror, epoll → mio·tokio, signalfd → signal-hook, fork·공유메모리 → nix·libc·repr(C), robust 뮤텍스는 C 유지 또는 unsafe 래핑), 임베디드 SQL 대책(DB 계층 C 유지 + FFI 권장, oracle·sqlx·tokio-postgres 재작성), 점진 이식(bindgen·cbindgen·Make 연동·같은 테스트 벡터 비교), 이식하지 말아야 할 경우, FFI 안전 체크리스트. 대상 경로 — **/*.rs, **/Cargo.toml, **/*.c, **/*.h, **/*.pc, **/*.pgc. 키워드 — C Rust 이식, FFI, bindgen, cbindgen, repr(C), catch_unwind, 임베디드 SQL Rust.
---

# C → Rust 이식

## 결론 먼저

질문: "C++ 사상을 C 문법으로 구현한 C 코드를 Rust로 같은 방식으로 구현할 수 있는가?"

1. **구조는 대부분 옮길 수 있다.** 불투명 핸들, ops 테이블, 역순 해제, 음수 에러 코드는 모두
   Rust에 대응 기능이 있다. 오히려 Rust에서는 이 패턴들이 언어 기능이라 더 짧고 안전하다.
2. **"같은 방식"은 아니다.** 패턴은 대응되지만 소유 구조를 다시 설계해야 한다.
   C에서 여러 곳이 같은 포인터를 들고 고치던 코드는 Rust에서 그대로 컴파일되지 않는다.
   누가 소유하고 누가 빌리는지를 먼저 정해야 한다.
3. **임베디드 SQL이 가장 큰 장벽이다.** Pro*C·ecpg에 해당하는 Rust 프리컴파일러는 없다.
   권장안은 DB 계층을 C로 두고 Rust에서 FFI로 부르는 것이다.
4. **공유메모리와 robust 프로세스 공유 뮤텍스는 안전한 표준 대응물이 없다.**
   C에 두거나 `unsafe` 경계 하나에 가두고 `// SAFETY:` 논증을 단다.
5. **한 번에 옮기지 않는다.** 모듈 하나씩, 같은 테스트 벡터로 C와 Rust 결과를 비교하며 바꾼다.
   동작하는 예제가 `templates/project/c-system/examples/ffi-rust/`에 있다(`make test`).

## 언제 사용하나

- C 모듈을 Rust로 옮길지 판단할 때
- C 서버에 Rust 모듈을 섞거나, Rust에서 기존 C 라이브러리를 부를 때
- FFI 경계 코드를 작성·리뷰할 때

### 언제 사용하지 않나

- 새 Rust 코드의 일반 패턴 → [rust-patterns](../rust-patterns/SKILL.md)
- 재사용 crate 배포 규율 → [rust-library-crate](../rust-library-crate/SKILL.md)
- C 서버 구조 자체 → [c-server-patterns](../c-server-patterns/SKILL.md)

## 1. 대응표

| C 패턴 | Rust 대응 | 주의 |
|---|---|---|
| 불투명 핸들 `typedef struct Conn Conn;` | 비공개 필드 구조체 + `impl` | 필드를 `pub`으로 열지 않는다. 생성 경로는 `new`·`TryFrom` 하나 |
| `ConnCreate`·`ConnDestroy` 쌍 | `new()` + `Drop` | 해제를 부를 필요가 없다. 이중 해제·누락이 컴파일 단계에서 사라진다 |
| ops 테이블 `XxxOps` | trait | 정적 디스패치(제네릭)와 동적 디스패치(`dyn Trait`) 중 선택 — 2절 |
| `void *impl` | 제네릭 타입 매개변수 또는 `Box<dyn Trait>` | `void *` 캐스팅이 사라진다 |
| goto 단일 정리 경로 | `Drop`·RAII, `?` 조기 반환 | 실패 지점마다 이미 획득한 것만 자동 해제된다 |
| 역순 해제 | 지역 변수는 선언 역순으로 drop | 구조체 필드는 **선언 순서**로 drop된다 — 3절 |
| `-errno`·도메인 음수 코드 | `Result<T, E>` + `thiserror` 열거형 | FFI 경계에서만 다시 정수 코드로 바꾼다 |
| `errno` 보존·`EINTR` 재시도 | `std::io::Error`, `ErrorKind::Interrupted` | 표준 I/O의 `read_exact`·`write_all`은 `EINTR`을 재시도한다 |
| epoll 루프 | `mio`(직접 루프) 또는 `tokio`(async) | 4절 |
| `signalfd`·self-pipe | `signal-hook`(+`signal-hook-mio`), `tokio::signal`, `nix::sys::signalfd` | 4절 |
| `timerfd`·`eventfd` | `mio`의 `Waker`, `tokio::time`, `nix` | |
| `fork`·`waitpid` | `nix::unistd::fork`(unsafe)·`nix::sys::wait` | 스레드·런타임을 만들기 전에만 fork한다 |
| 공유메모리 레이아웃 | `#[repr(C)]` 구조체 + 크기·오프셋 컴파일 검사 | 포인터 대신 인덱스·오프셋 |
| `shm_open`·`mmap` / `shmget`·`shmat` | `nix::sys::mman` / `libc` | SysV는 `libc`를 직접 쓴다 |
| `pthread_mutex`(프로세스 내부) | `std::sync::Mutex`, `parking_lot::Mutex` | 가드가 drop되면 자동 해제된다 |
| robust 프로세스 공유 뮤텍스 | **안전한 표준 대응물 없음** | C 유지 + FFI, 또는 `libc` 래핑 + `// SAFETY:` — 5절 |
| `pthread_create`·`join` | `std::thread::spawn`·`JoinHandle`, `std::thread::scope` | |
| 설정 포인터 원자적 교체 | `arc-swap`의 `ArcSwap<Config>` | 이전 설정 해제 시점을 직접 관리하지 않아도 된다 |
| X-매크로 필드 테이블 | `derive` 또는 `macro_rules!` | |
| Pro*C·ecpg | **대응물 없음** | 6절 |

## 2. ops 테이블 → trait

C의 ops 테이블과 Rust의 `dyn Trait`는 사실상 같은 구조다.
`Box<dyn Store>`는 (데이터 포인터, vtable 포인터) 쌍이고, vtable이 곧 ops 테이블이다.

```rust
/// C의 StoreOps에 대응하는 인터페이스. destroy는 Drop이 맡는다.
pub trait Store {
    fn add(&mut self, key: u32, delta: i64) -> Result<(), StoreError>;
    fn get(&self, key: u32) -> Result<i64, StoreError>;
}

// 정적 디스패치 — 컴파일 시점에 구현이 정해진다. 간접 호출이 없어 HOTPATH에 맞다.
pub struct Server<S: Store> {
    store: S,
}

// 동적 디스패치 — 설정으로 구현을 고를 때. C ops 테이블과 같은 비용(간접 호출 1회)이다.
pub fn make_store(kind: StoreKind) -> Box<dyn Store> {
    match kind {
        StoreKind::Mem => Box::new(MemStore::new()),
        StoreKind::Shm => Box::new(ShmStore::attach()),
    }
}
```

| 선택 | 언제 |
|---|---|
| 제네릭 `S: Store` | 구현이 빌드 시점에 하나로 정해지거나, 핫패스라 간접 호출을 피해야 할 때 |
| `Box<dyn Store>`·`&dyn Store` | 실행 중에 구현을 고르거나, 서로 다른 구현을 한 컬렉션에 담을 때 |
| `enum` 디스패치 | 구현 목록이 닫혀 있고 적을 때. 할당이 없고 `match`로 분기한다 |

C 테이블의 `version` 필드는 Rust 내부에서는 필요 없다. 트레이트가 바뀌면 컴파일이 막아 준다.
FFI로 C와 테이블을 주고받을 때만 `version`을 유지한다.

## 3. 수명과 해제 순서

- 지역 변수는 선언의 **역순**으로 drop된다. C의 "획득 역순 해제"와 같다.
- 구조체 필드는 선언 **순서대로** drop된다. 먼저 닫아야 할 모듈을 먼저 선언한다.

```rust
/// 필드 선언 순서 = 종료 순서. 시작 순서(log → shm → db → net)의 역순으로 적는다.
pub struct Server {
    net: Net,     // 가장 먼저 닫힌다 — 새 요청 차단
    db: Db,
    shm: ShmView,
    log: Log,     // 가장 늦게 닫힌다
}
```

- `Drop`은 에러를 돌려줄 수 없다. 커밋·flush처럼 실패를 보고해야 하는 종료 단계는
  `fn shutdown(self) -> Result<(), E>`로 명시적으로 부르고, `Drop`은 호출을 빠뜨렸을 때의 안전망으로만 둔다.
- 불가능한 상태는 타입으로 막는다. 예를 들어 `Connected`·`Closed` 상태를 서로 다른 타입으로 만들면
  닫힌 연결에 쓰는 코드가 컴파일되지 않는다.

## 4. 이벤트 루프와 시그널

| 선택 | 맞는 경우 |
|---|---|
| `mio` | C의 epoll 루프 구조를 그대로 옮기고 싶을 때. 루프·상태 기계를 직접 쓴다. 지연 예측성이 높다 |
| `tokio` | 연결 수가 많고 로직이 I/O 대기 위주일 때. 관리·수집 같은 주변부(D13) |
| 전용 스레드 + `mio` | 핫패스. 코어 고정과 busy-poll을 검토한다(D13) |

- C에서 LT·ET를 고르던 판단은 `mio`에서도 같다. `mio`는 ET로 동작하므로 `WouldBlock`까지 읽는다.
- 시그널은 `signal-hook`으로 받는다. `mio` 루프면 `signal-hook-mio`로 fd처럼 등록하고,
  `tokio`면 `tokio::signal::unix::signal(SignalKind::terminate())`를 `select!`에 넣는다.
- C와 같은 signalfd 구조가 필요하면 `nix::sys::signalfd::SignalFd`를 쓴다.
  이때도 스레드를 만들기 전에 시그널을 막는다.

## 5. fork·공유메모리·동기화

### fork

- `nix::unistd::fork`는 `unsafe`다. 다른 스레드가 있으면 자식에서 락·할당자가 깨질 수 있기 때문이다.
- `tokio` 런타임을 만들기 전, 스레드를 하나도 만들기 전에 fork한다. master는 단일 스레드로 둔다.
- 자식에서 할 일(epoll 재생성, DB 재연결, 공유메모리 attach)은 [c-server-patterns](../c-server-patterns/SKILL.md) 7절과 같다.

### 공유메모리 레이아웃

C와 Rust가 같은 세그먼트를 보려면 레이아웃을 양쪽에서 고정하고 검사한다.

```rust
/// C의 ShmHeader와 같은 레이아웃. 포인터 필드를 두지 않는다.
#[repr(C)]
pub struct ShmHeader {
    pub magic: u32,
    pub version: u32,
    pub record_size: u32,
    pub state: u32,
    pub record_cnt: u64,
}

// C의 _Static_assert(sizeof(ShmHeader) == 24, ...)와 같은 조건
const _: () = assert!(std::mem::size_of::<ShmHeader>() == 24);
const _: () = assert!(std::mem::offset_of!(ShmHeader, record_cnt) == 16);
```

- 다른 프로세스가 동시에 쓰는 메모리에 `&mut T`나 `&T`를 오래 만들어 두지 않는다.
  Rust 참조는 "그동안 아무도 안 바꾼다"는 약속이라 공유메모리에서는 거짓이 된다.
- 동시에 바뀌는 필드는 `AtomicU32`·`AtomicU64`로 읽고 쓴다(C11 `_Atomic`과 같은 크기·정렬).
- 레코드 묶음은 시퀀스 락이나 뮤텍스로 보호하고, `ptr::read_volatile`·복사 후 검증으로 읽는다.
- `static_assertions` crate의 `const_assert_eq!`·`assert_eq_size!`를 써도 된다.

### 동기화

- 프로세스 내부 락은 `std::sync::Mutex`나 `parking_lot::Mutex`로 바꾼다.
- **robust 프로세스 공유 뮤텍스는 안전한 표준 대응물이 없다.** 두 방법이 있다.
  - **권장**: 잠금·`EOWNERDEAD` 복구·`pthread_mutex_consistent`를 C 모듈에 두고 Rust는 FFI로 부른다.
    복구 절차가 이미 검증된 C 코드라면 이쪽이 위험이 작다.
  - **대안**: `libc::pthread_mutex_*`를 감싼 Rust 타입을 만든다. 뮤텍스는 공유메모리 안에서 움직이면 안 되므로
    값으로 들고 다니지 않고 포인터로만 다룬다. 모든 `unsafe` 블록에 `// SAFETY:` 논증을 단다.
- 어느 쪽이든 원칙은 [rules/systems/philosophy.md](../../rules/systems/philosophy.md) 11절의 공유 가변 상태 조건을 따른다.

## 6. 임베디드 SQL — 막히는 지점

Pro*C·ecpg는 C 소스의 `EXEC SQL`을 라이브러리 호출로 바꾸는 프리컴파일러다. Rust용은 없다.
그래서 선택지는 두 가지다.

| 선택 | 방법 | 장점 | 비용·위험 |
|---|---|---|---|
| **A. C 유지 + FFI (권장)** | `*.pc`·`*.pgc` DB 모듈을 그대로 두고, ops 테이블 형태의 C API를 Rust에서 부른다 | SQL·트랜잭션 의미가 바뀌지 않는다. 검증된 코드를 재사용한다 | 빌드에 프리컴파일러가 남는다. FFI 경계 관리 |
| B. 드라이버로 재작성 | Oracle은 `oracle` crate(ODPI-C 기반, 실행 시 Oracle Client 필요), PostgreSQL은 `sqlx`(async, 컴파일 시 쿼리 검사) 또는 `tokio-postgres`·`postgres`(동기) | 프리컴파일 단계가 사라진다. Rust 타입으로 결과를 받는다 | 동작 차이 위험이 크다 — 아래 표 |

재작성(B)을 고르면 다음 차이를 하나씩 확인한다.

| 항목 | 임베디드 SQL | 드라이버 | 확인 방법 |
|---|---|---|---|
| NULL | 인디케이터 변수 `-1` | `Option<T>` | NULL 포함 행으로 비교 테스트 |
| 숫자·날짜 | 호스트 변수 형 변환 규칙 | 드라이버 매핑(`NUMBER` 정밀도, 시간대) | 경계값 행 비교 |
| 대량 조회·적재 | 호스트 배열 | 배치 API·`COPY` | 같은 건수로 처리량 측정 |
| 에러 | `SQLCODE`·`SQLSTATE` | 드라이버 에러 타입 | 에러 코드 대응표 작성 |
| 트랜잭션 | 명시 `COMMIT`, 자동 커밋 없음 | 드라이버마다 기본값이 다르다 | 자동 커밋 설정을 명시 |

- `sqlx::query!`의 컴파일 시 검사는 DB 접속이나 오프라인 메타데이터(`cargo sqlx prepare`)가 필요하다.
  인터넷·DB가 없는 빌드 서버라면 메타데이터를 커밋한다.
- 바인드 파라미터 규칙은 `rules/rust/security.md`의 SQL 절을 따른다. 문자열로 SQL을 조립하지 않는다.
- 어느 쪽이든 공유메모리 ⇄ DB 동기화 규칙은 `shm-db-patterns` 스킬이 정본이다.

## 7. 점진 이식 절차

1. **대상 고르기**: 의존이 적고, ops 인터페이스가 이미 있고, 테스트가 있는 말단 모듈부터 한다.
2. **인터페이스 고정**: C 헤더(ops 테이블·에러 코드)를 이식 기간 동안 바꾸지 않는다.
3. **테스트 벡터 작성**: 입력과 기대 결과를 표로 만든다. 경계 조건(0, 최대값, 가득 참, 없는 키)을 넣는다.
4. **Rust 구현**: 같은 ops 테이블을 `#[repr(C)]`로 정의하고 `extern "C"`로 내보낸다. 빌드 산출물은 `staticlib`이다.
5. **헤더 생성**: Rust가 내보내는 심볼의 C 헤더는 `cbindgen`으로 만든다.
   Rust가 C를 부르는 쪽(예: DB 모듈)은 `bindgen`으로 바인딩을 만든다.
   인터넷 없는 서버를 고려해 생성 결과를 커밋하고, 생성 명령은 Makefile 대상으로 둔다.
6. **빌드 연동**: Makefile이 `cargo build --release`를 부르고 `lib<이름>.a`를 링크한다.
   재빌드 판단은 cargo에 맡긴다. Rust 표준 라이브러리가 요구하는 시스템 라이브러리 목록은
   `cargo rustc --release -- --print native-static-libs`로 확인한다.
7. **차분 비교**: 같은 테스트 벡터를 C 구현과 Rust 구현에 같은 ops 테이블로 돌리고, 단계별 결과를 비교한다.
   기대값과의 비교와 별개로 "두 구현이 같은가"를 따로 검사한다.
8. **전환**: 설정이나 링크 선택으로 Rust 구현을 운영에 넣는다. C 구현은 안정 기간 동안 남겨 되돌릴 수 있게 한다.
9. **정리**: 안정 기간이 지나면 C 구현을 지운다. 인터페이스가 Rust 쪽으로만 쓰이면 그때 Rust다운 API로 바꾼다.

### 예제 — `templates/project/c-system/examples/ffi-rust/`

| 파일 | 역할 |
|---|---|
| `include/counter.h` | ops 테이블 `CounterOps`(version 필드 포함), 불투명 핸들 `Counter`, 도메인 에러 코드 |
| `src/counter.c`·`src/counter_mem.c` | 핸들 계층과 C 구현 |
| `rust/src/lib.rs` | 비공개 필드 구조체 `MemCounter` + trait `Counter` |
| `rust/src/ffi.rs` | `#[repr(C)]` 테이블 `COUNTER_RS_OPS`, NULL 검사, `catch_unwind`, 에러 코드 변환, 크기 컴파일 검사 |
| `include/counter_rs.h` | Rust 심볼 선언 — `cbindgen` 출력에 해당 |
| `tests/test_counter.c` | 같은 벡터를 두 구현에 돌려 기대값·차분 비교, 레이아웃 크기 비교 |
| `Makefile` | `make test` — cargo가 없으면 C 구현만 검사하고 그 사실을 알린다 |

## 8. 이식하지 말아야 할 경우

- 오래 안정적으로 돌고, 바꿀 계획도 없고, 메모리 안전 사고 이력도 없는 모듈. 이식 비용만 생긴다.
- 임베디드 SQL이 대부분인 모듈. 6절 A안처럼 C로 두는 편이 낫다.
- 공유메모리·robust 뮤텍스 위주라 Rust로 옮겨도 대부분이 `unsafe`가 되는 모듈.
- 팀이 Rust 코드를 리뷰·운영할 준비가 안 된 경우. 새벽 장애에 읽을 사람이 없으면 안전성 이득이 사라진다.
- 성능이 이유인 경우. Rust라서 빨라지지는 않는다. 먼저 C에서 측정하고 병목을 찾는다.

옮길 가치가 큰 쪽은 외부 입력 파싱(프로토콜·설정), 복잡한 상태 기계, 동시성이 얽힌 새 모듈이다.

## 9. FFI 안전 체크리스트

- [ ] **NULL**: C에서 받은 모든 포인터를 경계에서 검사하고 에러 코드를 돌려준다.
- [ ] **수명**: Rust가 C 포인터를 함수 호출 너머로 저장하지 않는다. 저장해야 하면 수명 계약을 헤더에 적는다.
- [ ] **소유권 이전**: Rust가 만든 객체는 `Box::into_raw`로 넘기고, 같은 crate의 해제 함수가 `Box::from_raw`로 정확히 한 번 돌려받는다.
      C `free`로 Rust 메모리를, Rust `drop`으로 C 메모리를 해제하지 않는다.
- [ ] **panic**: `extern "C"` 함수 본문을 `catch_unwind`로 감싸고 panic을 에러 코드로 바꾼다.
      Rust 1.81부터 경계를 넘는 panic은 프로세스를 abort시킨다. 릴리스 프로필은 `panic = "unwind"`여야 잡힌다.
      할당 실패(OOM)는 panic이 아니라 abort라서 잡히지 않는다. C처럼 NULL을 돌려줘야 하면 `try_reserve` 같은 실패 가능 할당을 쓴다.
- [ ] **에러 변환**: `Result`의 에러를 C 에러 코드로 바꾸는 함수를 한 곳에 두고, 코드 값은 C 헤더와 같게 유지한다.
- [ ] **레이아웃**: 경계를 넘는 구조체는 `#[repr(C)]`다. 크기·오프셋을 Rust(`const assert`·`static_assertions`)와
      C(`_Static_assert`) 양쪽에서 검사하고, 실행 중에도 한 번 비교한다.
- [ ] **열거형**: C에서 오는 정수를 Rust `enum`으로 바로 변환하지 않는다. 범위 밖 값은 UB다. 정수로 받고 `TryFrom`으로 검사한다.
- [ ] **문자열**: `CStr`·`CString`으로 다룬다. NUL 종료와 UTF-8 여부를 경계에서 검사한다.
- [ ] **스레드**: C가 핸들을 여러 스레드에서 부르면 Rust 타입이 `Send`·`Sync`여야 한다. 아니면 헤더에 "단일 스레드 전용"을 적는다.
- [ ] **unsafe 격리**: `unsafe`는 `ffi` 모듈에만 둔다. 각 블록에 `// SAFETY:`로 어떤 불변식 때문에 안전한지 적는다.
      `#![deny(unsafe_op_in_unsafe_fn)]`로 블록 단위 논증을 강제한다(Rust 2024는 기본 경고).
- [ ] **심볼**: 내보내는 함수는 `#[no_mangle]`(Rust 2024는 `#[unsafe(no_mangle)]`)과 `extern "C"`를 쓴다.
- [ ] **검증**: `cargo test`, `cargo +nightly miri test`(가능한 범위), C 쪽 ASan 빌드로 경계 테스트를 돌린다.

## 관련 스킬

- [c-server-patterns](../c-server-patterns/SKILL.md) — 이식 대상 C 서버 구조
- [rust-patterns](../rust-patterns/SKILL.md) · [rust-testing](../rust-testing/SKILL.md) — Rust 쪽 패턴·테스트
- [embedded-sql](../embedded-sql/SKILL.md) — C로 남길 DB 계층
- [memory-check](../memory-check/SKILL.md) — ASan·valgrind로 경계 검증
- `shm-db-patterns` 스킬 — 공유메모리 ⇄ DB 데이터 계층
