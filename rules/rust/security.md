---
paths:
  - "**/*.rs"
  - "**/Cargo.toml"
  - "**/Cargo.lock"
---
# Rust 보안

> [common/security.md](../common/security.md) 를 확장한다.

## unsafe 블록 규칙

- `unsafe` 는 최소 범위로 격리하고 바로 위에 안전성 근거(`// SAFETY:`) 주석 필수
- 안전한 대안이 있으면 `unsafe` 금지 — 성능 측정으로 정당화된 경우만 허용
- crate 단위로 `#![forbid(unsafe_code)]` 우선, 불가피한 모듈만 예외

```rust
// SAFETY: idx < len 을 호출부에서 검증했으므로 경계 내 접근 보장
let tick = unsafe { buf.get_unchecked(idx) };
```

- `// SAFETY:` 는 "안전함"이 아니라 **어떤 불변식이 성립하므로 안전한지** 그 논증을
  적는다 (regex-automata 는 unsafe 57곳마다 근거 주석 병행).
- `unsafe impl` 트레이트에도 각 메서드 구현이 왜 계약을 지키는지 근거를 남긴다.

## 메모리 안전성

- 미정의 동작 검출: `cargo +nightly miri test` (unsafe·FFI 있으면 CI 필수)
- 정수 오버플로 — 핫패스는 `wrapping_*`/`checked_*` 명시, 디버그 빌드 패닉 의존 금지
- FFI 경계에서 널 포인터·정렬·수명 직접 검증
- **바이트 직렬화·`transmute`·정렬 가정**은 빅엔디안·32비트에서 깨질 수 있다 —
  크로스 타깃(`i686`·`s390x` 등) CI 로 검증 (`skills/rust-library-crate/SKILL.md`)
- **적대적 입력 방어는 퍼징으로** — 파서·역직렬화는 `cargo fuzz` 로 패닉·UB·DoS
  (무한루프·과대 할당) 를 상시 검출 (`rules/rust/testing.md`)

## SQL 바인드 파라미터

쿼리 문자열에 값을 `format!`으로 끼워 넣지 않는다. sqlx는 PostgreSQL의 `$1`, `$2` 자리표시자에 값을 바인드한다.
`query!` 매크로는 컴파일 시점에 스키마까지 검증한다. 정렬 컬럼처럼 바인드할 수 없는 식별자는 열거형으로 받는다.

```rust
let user = sqlx::query_as::<_, User>("SELECT id, name FROM users WHERE email = $1")
    .bind(email.as_str())
    .fetch_optional(&pool)
    .await?;
```

## 검증 대신 파싱 — newtype 경계

외부 입력은 경계에서 한 번 **파싱**해 newtype으로 바꾼다. 안쪽 함수는 그 타입만 받으므로 재검증이 필요 없다.
개인정보 newtype은 `Debug`·`Display`를 직접 구현해 마스킹한 값만 출력한다.

```rust
pub struct AccountNo(String);   // 필드 비공개 — 생성 경로는 TryFrom 하나뿐

impl TryFrom<&str> for AccountNo {
    type Error = InputError;
    fn try_from(raw: &str) -> Result<Self, Self::Error> {
        let ok = (10..=14).contains(&raw.len()) && raw.bytes().all(|b| b.is_ascii_digit());
        if ok { Ok(Self(raw.to_owned())) } else { Err(InputError::InvalidAccountNo) }
    }
}
```

## 외부 에러 응답 일반화

클라이언트에는 일반화한 메시지와 요청 ID만 보내고, 원인과 상세는 내부 `tracing` 로그에 남긴다.
`sqlx::Error`·파일 경로·스택은 응답에 넣지 않는다. 입력 오류(400)만 어떤 필드가 틀렸는지 알려 준다.

```rust
impl IntoResponse for AppError {
    fn into_response(self) -> Response {
        let request_id = Uuid::new_v4();
        tracing::error!(%request_id, error = ?self, "요청 처리 실패");   // 상세는 내부 로그로
        let body = Json(json!({ "error": "internal_error", "requestId": request_id }));
        (StatusCode::INTERNAL_SERVER_ERROR, body).into_response()
    }
}
```

## 비밀값 관리

```rust
let key = std::env::var("API_KEY")
    .expect("API_KEY 환경변수 필요");   // 시작 시점 검증만 expect 허용
```
- 비밀값은 `secrecy::Secret<T>` 로 감싸 로그·`Debug` 출력 노출 차단.
- 메모리에 남는 키·비밀번호는 `zeroize`(`Zeroizing<T>`, `#[derive(ZeroizeOnDrop)]`)로 사용 후 지운다(`secrecy`도 드롭 시 소거).
  로그 마스킹·저장 기준은 `skills/sensitive-data-handling/SKILL.md`를 따른다.

## 공급망 보안

```bash
cargo audit                      # RustSec 취약점 DB 대조
cargo deny check                 # 라이선스·중복·금지 crate 검사
cargo update --locked            # Cargo.lock 고정 빌드
```

- 의존성 추가 시 다운로드 수·관리 상태·`unsafe` 사용량 검토
- `Cargo.lock` 커밋 필수 (바이너리·재현 빌드 보장)
