---
name: sensitive-data-handling
description: 비밀값(키·비밀번호·토큰·DB 접속 정보)과 개인정보(주민등록번호·카드·계좌번호·연락처·고객 식별자)를 다루는 기술적 통제 — 최소 수집·파기, 로그·코어 덤프 마스킹, 저장 암호화(TDE·pgcrypto), argon2id 비밀번호 해시, 전송 TLS, 합성 테스트 데이터, 공유메모리·클라이언트 저장, 외부 전송 금지, DB 마스킹 뷰. 대상 경로 — **/*.c, **/*.h, **/*.pc, **/*.pgc, **/*.rs, **/*.ts, **/*.tsx, **/*.sql. 키워드 — 개인정보, 민감정보, 마스킹, 비밀번호 해시, 합성 데이터, 코어 덤프, 암호화, safeStorage.
---

# 민감정보 처리

비밀값과 개인정보는 **적게 모으고, 짧게 보관하고, 보이는 곳마다 가린다.** 이 스킬은 그 원칙을
코드·DB·운영 절차의 기술적 통제로 옮긴다.

## 범위와 우선순위

- **대상 — 비밀값**: API 키, 비밀번호, 토큰, 개인키, DB 접속 정보(계정·비밀번호·접속 문자열).
- **대상 — 개인정보**: 주민등록번호, 카드번호, 계좌번호, 연락처(전화·이메일·주소), 고객 식별자.
- **법적 해석은 범위 밖이다.** 개인정보보호법·신용정보법의 요건 해석(보존 기간, 암호화 의무 대상 등)은
  담당 부서가 판단한다. 하네스는 기술적 통제만 다룬다.
- **회사 정책 문서가 있으면 그 문서가 우선한다.** 이 스킬은 정책이 없을 때의 기본값이다.

## 언제 사용하나

- 위 대상 데이터를 읽고, 저장하고, 로그로 남기고, 전송하는 코드를 작성하거나 리뷰할 때
- 로그인·인증, 고객 조회 화면, 배치 추출, 공유메모리 적재 기능을 설계할 때
- 테스트 데이터를 만들거나 운영 데이터로 장애를 재현하려 할 때
- 세션 요약·handoff·이슈·외부 도구에 작업 내용을 옮겨 적을 때

### 언제 사용하지 않나

- 인증·인가·인젝션 같은 일반 취약점 점검 → `security-review`
- Claude Code 설정 파일 자체의 보안 점검 → `security-scan`

## 핵심 원칙

### ① 최소 수집·보존·파기

- 기능에 꼭 필요한 필드만 받는다. 화면 표시에 카드 끝 4자리만 필요하면 끝 4자리만 저장한다.
- 원문이 필요 없는 조회 키는 원문 대신 내부 고객 번호나 토큰을 쓴다.
- 테이블마다 보존 기간과 파기 방법(삭제 배치, 백업 만료)을 설계 문서에 적는다. 기간은 담당 부서가 정한다.
- 파기는 운영 테이블뿐 아니라 백업, 추출 파일, 로그, 캐시까지 포함한다.

### ② 로그·에러·크래시·코어 덤프 마스킹

- 마스킹은 **필드 단위**로 한다. 로그 문자열 전체에 정규식을 거는 사후 필터는 새는 경우가 생기므로 보조 수단으로만 쓴다.
- 비밀값은 마스킹하지 않고 **아예 기록하지 않는다.** 비밀번호의 앞 두 글자도 남기지 않는다.
- 개인정보는 식별에 필요한 최소 자리만 남긴다. 아래는 기본 형식이다.

| 항목 | 기본 마스킹 형식 |
|---|---|
| 주민등록번호 | 생년월일 6자리와 성별 1자리만 남김 (`YYMMDD-N******`) |
| 카드번호 | 앞 6자리와 끝 4자리만 남김 |
| 계좌번호 | 끝 4자리만 남김 |
| 전화번호 | 앞 3자리와 끝 4자리만 남김 (`010-****-5678`) |
| 이메일 | 첫 글자와 도메인만 남김 (`k***@example.com`) |

- 에러 응답에는 일반화한 메시지와 요청 ID만 보낸다. SQL 문, 바인드 값, 스택은 내부 로그로만 보낸다.
- 크래시 리포트(Sentry 등)는 전송 전 훅(`beforeSend`)에서 요청 본문·헤더·쿠키를 지운다.
- **비밀값을 메모리에 들고 있는 프로세스는 코어 덤프를 끈다.** 코어 파일에는 힙 전체가 들어간다.
  `setrlimit(RLIMIT_CORE)`를 0으로 두고 Linux에서는 `prctl(PR_SET_DUMPABLE, 0)`도 호출한다(예시 참조).
  덤프를 살려야 하는 프로세스라면 비밀 버퍼만 `madvise(MADV_DONTDUMP)`로 제외한다.
- 비밀 버퍼는 사용 직후 `explicit_bzero`(C), `zeroize`(Rust)로 지운다. `memset`은 컴파일러가 없앨 수 있다.

### ③ 저장 시 보호

- **Oracle**: 개인정보 컬럼은 TDE(Transparent Data Encryption) 컬럼 암호화나 암호화 테이블스페이스에 둔다.
  키는 Oracle 지갑(wallet)이나 외부 키 저장소에 둔다.
- **PostgreSQL**: 컬럼 단위로 `pgcrypto`를 쓴다. 키는 애플리케이션이 바인드 값으로 넘긴다.

```sql
-- Oracle: 컬럼 암호화 (지갑이 열려 있어야 한다)
ALTER TABLE customers MODIFY (rrn ENCRYPT USING 'AES256');

-- PostgreSQL: pgcrypto 대칭 암호화. :enc_key 는 앱이 바인드하는 값이다
INSERT INTO customers (customer_id, acct_no_enc)
VALUES (:customer_id, pgp_sym_encrypt(:acct_no, :enc_key));
```

- **키는 코드와 DB 밖에 둔다.** 개발 Mac은 키체인, 서버는 권한 600 파일이나 환경변수, 가능하면 키 관리 서비스(KMS)를 쓴다.
  키를 같은 DB 테이블에 두면 DB 덤프 하나로 암호화가 무의미해진다.
- TDE는 디스크·백업 유출을 막을 뿐이다. SELECT 권한이 있는 계정에는 평문이 보이므로 ⑩의 권한 분리와 함께 쓴다.

### ④ 비밀번호는 해시만 저장

- 비밀번호는 평문이나 복호화 가능한 형태로 저장하지 않는다. **argon2id 해시만** 저장한다.
- C에서는 libsodium `crypto_pwhash_str`(기본 알고리즘 argon2id)로 해시하고 `crypto_pwhash_str_verify`로 검증한다.
  검증 함수는 내부에서 상수 시간 비교를 한다. `strcmp`·`memcmp`로 해시를 직접 비교하지 않는다(예시 참조).
- 해시 문자열에는 알고리즘·파라미터·솔트가 함께 들어 있으므로 별도 솔트 컬럼이 필요 없다.
- 파라미터를 올렸다면 로그인 성공 시 `crypto_pwhash_str_needs_rehash`로 확인해 다시 해시한다.

### ⑤ 전송 구간 TLS

- 외부 API, 브라우저, 서버 간 통신은 TLS 1.2 이상을 쓴다.
- DB 접속도 암호화한다. PostgreSQL은 `sslmode=verify-full`, Oracle은 TCPS나 네이티브 네트워크 암호화를 쓴다.
- 인증서 검증을 끄지 않는다(`curl -k`, `rejectUnauthorized: false`, `sslmode=require`만 쓰고 검증 생략).
- 같은 호스트 안의 IPC는 유닉스 도메인 소켓과 파일 권한(0600·0660)으로 보호한다.

### ⑥ 테스트·개발은 합성 데이터만

- 테스트·개발·스테이징에는 **합성 데이터만** 쓴다. 운영 덤프를 개발 환경이나 로컬로 반출하지 않는다.
- 장애 재현에 운영 데이터 형태가 필요하면 마스킹 뷰(⑩)로 추출하거나 같은 분포의 합성 데이터를 만든다.
- 합성 주민등록번호·카드번호는 **검증 자리가 맞지 않게** 만든다. 검증식이 맞으면 실제 번호와 구분할 수 없다.
- 하네스의 `hooks/guard-secrets.sh`는 `git commit` 직전에 스테이징된 변경을 검사해 비밀값과
  검증식이 맞는 주민등록번호·카드번호가 있으면 커밋을 막는다. 연락처·이메일이 많은 파일과 데이터 파일
  (`*.csv`, `*.dump` 등)은 커밋 전에 확인을 요청한다.
- 합성 데이터 파일은 **파일 앞 20줄 안에** `ARACHNE-SYNTHETIC-DATA` 표식을 넣는다. 그러면 개인정보 검사를 건너뛴다.
  `tests/fixtures/`·`testdata/` 경로도 같은 취급을 받는다.
- 테스트용 가짜 비밀값이 든 줄에는 `ARACHNE-ALLOW-SECRET` 표식을 줄 단위로 단다. 파일 표식은 비밀값 검사를 면제하지 않는다.
- 표식은 실수 방지용이다. 진짜 데이터에 표식을 붙여 검사를 우회하지 않는다.

### ⑦ 공유메모리 내 개인정보

- 공유메모리에는 처리에 필요한 **최소 필드만** 적재한다. 주민등록번호 원문 대신 내부 고객 번호를 쓴다.
- 세그먼트 권한은 0600(같은 그룹 프로세스가 필요하면 0660)으로 만든다.
- 공유메모리 조회·덤프 도구는 **기본 출력을 마스킹**한다. 원문 보기 옵션은 권한 확인과 감사 로그를 거친다.
- 슬롯을 비울 때는 개인정보 필드를 0으로 지운 뒤 반환한다. 재사용된 슬롯에 이전 고객 데이터가 남지 않게 한다.

### ⑧ 클라이언트 저장

- 브라우저 `localStorage`·`sessionStorage`·IndexedDB에는 토큰·비밀값·개인정보를 두지 않는다. 세션은 `HttpOnly` 쿠키로 유지한다.
- Electron은 `safeStorage.encryptString`으로 암호화한 뒤 앱 데이터 경로에 저장한다. 저장 전에
  `safeStorage.isEncryptionAvailable()`을 확인하고, 불가하면 평문으로 대체하지 말고 저장을 거부한다.
- 네이티브 클라이언트와 개발 도구는 OS 키체인(macOS Keychain, Windows 자격 증명 관리자, libsecret)을 쓴다.

### ⑨ 외부 서비스로 보내지 않는다

- 비밀값·개인정보·고객 데이터를 외부 서비스에 붙여 넣지 않는다. MCP 도구, 웹 검색, 아티팩트,
  이슈 트래커, 채팅, 번역기, 붙여넣기 사이트가 모두 해당한다.
- Claude가 작업 중 로그나 덤프에서 개인정보를 보았다면 응답·세션 요약·handoff·커밋 메시지에는
  마스킹한 값이나 "파일:줄" 위치만 적는다.
- 버그 리포트에 첨부하는 로그는 마스킹 도구를 거친 사본만 쓴다.

### ⑩ DB 마스킹 뷰와 권한 분리

- 원본 테이블 접근은 처리 계정만 갖는다. 조회·운영·분석 계정은 마스킹 뷰만 읽는다.
- Oracle은 Data Redaction(`DBMS_REDACT`)이나 마스킹 뷰를, PostgreSQL은 마스킹 뷰와 행 수준 보안(RLS)을 쓴다.

```sql
-- PostgreSQL: 마스킹 뷰와 권한 분리
CREATE VIEW customers_masked AS
SELECT customer_id,
       left(phone, 3) || '-****-' || right(phone, 4) AS phone,
       '****-' || acct_no_last4                      AS acct_no
FROM   customers;

REVOKE ALL    ON customers        FROM app_readonly;
GRANT  SELECT ON customers_masked TO   app_readonly;
```

- 애플리케이션 계정·배치 계정·운영자 계정을 나눈다. 한 계정이 모든 권한을 갖지 않게 한다.

## 예시

### C — 필드 단위 마스킹 헬퍼

```c
/*#############################################################################
FILE NAME   : pii_mask.c
DESCRIPTION : 로그·에러 출력용 개인정보 마스킹 헬퍼
#############################################################################*/
#include <stddef.h>

/*=============================================================================
FUNCTION    : MaskDigits
DESCRIPTION : 숫자 중 앞 keep_head개와 뒤 keep_tail개만 남기고 나머지 숫자를
              '*'로 바꾼다. 구분자('-', ' ')는 그대로 둔다. 숫자 수가 남길 자리
              수 이하이면 전부 가린다. 결과는 항상 NUL로 끝난다.
PARAMETERS  : const char *src       - 원문 (NULL이면 빈 문자열)
              size_t      keep_head - 앞에서 남길 숫자 수
              size_t      keep_tail - 뒤에서 남길 숫자 수
              char       *dst       - 출력 버퍼
              size_t      dst_size  - 출력 버퍼 크기
RETURNED    : dst
=============================================================================*/
char *MaskDigits(const char *src, size_t keep_head, size_t keep_tail,
                 char *dst, size_t dst_size)
{
    size_t digit_total = 0;
    size_t digit_seen  = 0;
    size_t ii          = 0;
    int    mask_all    = 0;

    if (dst == NULL || dst_size == 0)
    {
        return dst;
    }
    if (src == NULL)
    {
        dst[0] = '\0';
        return dst;
    }

    for (ii = 0; src[ii] != '\0'; ii++)
    {
        if (src[ii] >= '0' && src[ii] <= '9')
        {
            digit_total++;
        }
    }
    mask_all = (digit_total <= keep_head + keep_tail);

    for (ii = 0; src[ii] != '\0' && ii + 1 < dst_size; ii++)
    {
        char ch = src[ii];

        if (ch >= '0' && ch <= '9')
        {
            int keep = !mask_all
                       && (digit_seen < keep_head
                           || digit_seen >= digit_total - keep_tail);
            dst[ii] = keep ? ch : '*';
            digit_seen++;
        }
        else
        {
            dst[ii] = ch;
        }
    }
    dst[ii] = '\0';
    return dst;
}
```

사용 예: 전화번호는 `MaskDigits(phone, 3, 4, buf, sizeof(buf))`로 `010-****-5678`이 되고,
주민등록번호는 `MaskDigits(rrn, 7, 0, buf, sizeof(buf))`로 뒤 6자리가 가려진다.
로그 호출부에서는 원문 변수 대신 마스킹 결과만 넘긴다.

### C — 코어 덤프 차단

```c
#include <sys/prctl.h>
#include <sys/resource.h>

/*=============================================================================
FUNCTION    : DisableCoreDump
DESCRIPTION : 비밀값을 메모리에 들고 있는 프로세스의 코어 덤프를 끄고, 같은 사용자의
              ptrace 접근과 /proc/<pid>/mem 읽기도 막는다(Linux). 시작 직후 호출한다.
RETURNED    : 0 성공 / -1 실패
=============================================================================*/
int DisableCoreDump(void)
{
    struct rlimit no_core = { 0, 0 };

    if (setrlimit(RLIMIT_CORE, &no_core) != 0)
    {
        return -1;
    }
    if (prctl(PR_SET_DUMPABLE, 0, 0, 0, 0) != 0)
    {
        return -1;
    }
    return 0;
}
```

### C — argon2id 비밀번호 해시 (libsodium)

```c
#include <string.h>
#include <sodium.h>

/*=============================================================================
FUNCTION    : HashPassword
DESCRIPTION : 평문 비밀번호를 argon2id 해시 문자열로 바꾼다. 프로세스 시작 시
              sodium_init()을 먼저 호출해야 한다. 평문 버퍼는 호출 측이 지운다.
PARAMETERS  : const char *password - 평문 비밀번호
              char       *out_hash - crypto_pwhash_STRBYTES 크기 이상의 버퍼
RETURNED    : 0 성공 / -1 실패(메모리 부족 등)
=============================================================================*/
int HashPassword(const char *password, char out_hash[crypto_pwhash_STRBYTES])
{
    if (crypto_pwhash_str(out_hash, password, strlen(password),
                          crypto_pwhash_OPSLIMIT_INTERACTIVE,
                          crypto_pwhash_MEMLIMIT_INTERACTIVE) != 0)
    {
        return -1;
    }
    return 0;
}

/*=============================================================================
FUNCTION    : VerifyPassword
DESCRIPTION : 저장된 해시와 입력 비밀번호를 비교한다. 비교는 libsodium 내부의
              상수 시간 비교로 이루어진다.
PARAMETERS  : const char *stored_hash - DB에 저장된 해시 문자열
              const char *password    - 입력 비밀번호
RETURNED    : 1 일치 / 0 불일치
=============================================================================*/
int VerifyPassword(const char *stored_hash, const char *password)
{
    return crypto_pwhash_str_verify(stored_hash, password, strlen(password)) == 0;
}
```

호출 측은 검증이 끝나면 입력 버퍼를 지운다.

```c
char input_pass[128];

/* ... 입력 수신 ... */
int ok = VerifyPassword(stored_hash, input_pass);
explicit_bzero(input_pass, sizeof(input_pass));
```

`OPSLIMIT`·`MEMLIMIT`은 로그인 서버의 동시 처리량을 보고 정한다. `INTERACTIVE`는 해시 하나에 64MiB를 쓴다.

### TypeScript — 마스킹 헬퍼와 구조적 로그

```typescript
/*=============================================================================
FUNCTION    : MaskDigits
DESCRIPTION : 숫자 중 앞 keepHead개와 뒤 keepTail개만 남기고 나머지 숫자를 가린다.
              숫자 수가 남길 자리 수 이하이면 전부 가린다.
PARAMETERS  : string raw      - 원문
              number keepHead - 앞에서 남길 숫자 수
              number keepTail - 뒤에서 남길 숫자 수
RETURNED    : 마스킹한 문자열
=============================================================================*/
export function MaskDigits(raw: string, keepHead: number, keepTail: number): string {
    const total = raw.replace(/\D/g, "").length;
    if (total <= keepHead + keepTail) {
        return raw.replace(/\d/g, "*");
    }
    let seen = 0;
    return raw.replace(/\d/g, (digit) => {
        const keep = seen < keepHead || seen >= total - keepTail;
        seen += 1;
        return keep ? digit : "*";
    });
}

/*=============================================================================
FUNCTION    : MaskEmail
DESCRIPTION : 이메일의 첫 글자와 도메인만 남긴다.
PARAMETERS  : string raw - 원문 이메일
RETURNED    : 마스킹한 이메일 (형식이 맞지 않으면 "***")
=============================================================================*/
export function MaskEmail(raw: string): string {
    const at = raw.indexOf("@");
    if (at <= 0) {
        return "***";
    }
    return `${raw[0]}***${raw.slice(at)}`;
}

/* 구조적 로그: 필드 단위로 가리고, 비밀값 필드는 경로로 지운다 (pino) */
import pino from "pino";

const logger = pino({ redact: { paths: ["password", "token", "*.cardNo"], remove: true } });

logger.info({ customerId, phone: MaskDigits(phone, 3, 4) }, "고객 연락처 변경");
```

### Electron — 토큰 저장

```typescript
import { app, safeStorage } from "electron";
import { writeFileSync } from "node:fs";
import { join } from "node:path";

/*=============================================================================
FUNCTION    : SaveToken
DESCRIPTION : OS 키체인과 연동된 safeStorage로 토큰을 암호화해 저장한다.
              암호화를 쓸 수 없으면 평문 저장 대신 실패로 처리한다.
PARAMETERS  : string token - 저장할 토큰
=============================================================================*/
export function SaveToken(token: string): void {
    if (!safeStorage.isEncryptionAvailable()) {
        throw new Error("안전한 저장소를 사용할 수 없습니다");
    }
    const encrypted = safeStorage.encryptString(token);
    writeFileSync(join(app.getPath("userData"), "session.bin"), encrypted, { mode: 0o600 });
}
```

## 커밋 전 체크리스트

- [ ] 로그·에러·크래시 리포트에 비밀값이 없고, 개인정보는 필드 단위로 마스킹했다
- [ ] 비밀값을 든 프로세스는 코어 덤프를 껐고, 비밀 버퍼는 사용 후 지운다
- [ ] 개인정보 컬럼은 암호화하거나 마스킹 뷰 뒤에 있고, 키는 코드·DB 밖에 있다
- [ ] 비밀번호는 argon2id 해시만 저장하고 라이브러리 검증 함수로 비교한다
- [ ] 테스트 데이터는 합성 데이터이고, 표식(`ARACHNE-SYNTHETIC-DATA`, `ARACHNE-ALLOW-SECRET`)은 진짜 데이터에 쓰지 않았다
- [ ] 세션 요약·handoff·이슈·외부 도구에 원문을 옮기지 않았다

## 관련

- 언어별 규칙: `rules/c/security.md`, `rules/cpp/security.md`, `rules/rust/security.md`, `rules/javascript/security.md`
- 임베디드 SQL 접속 정보: `skills/embedded-sql/SKILL.md` 보안 체크
- 일반 보안 점검: `skills/security-review/SKILL.md`
