---
paths:
  - "**/*.c"
  - "**/*.h"
  - "**/*.pc"
  - "**/*.pgc"
---
# C 보안

> [common/security.md](../common/security.md) 를 확장한다.

## 메모리 안전성

```c
/* BAD: 경계 없는 복사 */
strcpy(buf, user_input);
sprintf(buf, user_input);

/* GOOD: 경계 제한 — 1순위, 항상 NUL 종료 */
snprintf(buf, sizeof(buf), "%s", user_input);

/* 레거시 호환: strncpy는 NUL 종료를 보장하지 않고 남는 공간을 0으로 채운다.
   기존 코드 유지 시에만, 반드시 수동 종료와 함께 */
strncpy(buf, user_input, sizeof(buf) - 1);
buf[sizeof(buf) - 1] = '\0';
```

- `gets()` 절대 사용 금지 → `fgets()` 사용
- `scanf("%s")` 금지 → `scanf("%255s")` 처럼 크기 제한

## 포맷 스트링 취약점

```c
/* BAD: 사용자 입력을 포맷 문자열로 사용 */
printf(user_input);
syslog(LOG_INFO, user_input);

/* GOOD: 포맷 문자열 고정 */
printf("%s", user_input);
syslog(LOG_INFO, "%s", user_input);
```

## 정수 오버플로

```c
/* BAD: 오버플로 검사 없는 산술 */
size_t total = count * item_size;
char *buf = malloc(total);

/* GOOD: 오버플로 검사 */
if (count > SIZE_MAX / item_size) { return ERR_OVERFLOW; }
size_t total = count * item_size;
char *buf = malloc(total);
if (!buf) { return ERR_NO_MEM; }
```

## POSIX 권한

```c
/* 파일 생성 시 권한 명시 */
int fd = open(path, O_CREAT | O_WRONLY, 0600);  /* 소유자만 읽기·쓰기 */

/* 소켓 파일 권한 */
chmod(SOCK_PATH, 0660);

/* umask 설정 (데몬 시작 시) */
umask(0027);
```

## setuid/setgid 처리

```c
/* 권한 상승 후 즉시 드롭 */
if (setuid(getuid()) < 0)
{
    perror("setuid");
    exit(1);
}
```

## 민감정보

- 로그에는 개인정보(주민등록번호·카드·계좌번호·연락처)를 필드 단위로 마스킹한 값만 남긴다. 비밀값은 마스킹도 하지 않고 아예 빼낸다.
- 비밀번호·키를 담은 버퍼는 사용 직후 `explicit_bzero(buf, sizeof(buf))`로 지운다. `memset`은 최적화로 제거될 수 있다.
- 마스킹 헬퍼·코어 덤프 차단·저장 기준은 `skills/sensitive-data-handling/SKILL.md`를 따른다.

## 정적 분석 도구

```bash
# cppcheck
cppcheck --enable=all --error-exitcode=1 src/

# AddressSanitizer
gcc -fsanitize=address,undefined -o binary src/*.c && ./binary

# Valgrind
valgrind --leak-check=full --error-exitcode=1 ./binary
```

## 빌드 하드닝 플래그

메모리 오류가 남아 있어도 악용을 어렵게 만드는 마지막 방어층이다. 배포·운영용 빌드에는 항상 켠다.

```make
HARDEN_CFLAGS  = -O2 -U_FORTIFY_SOURCE -D_FORTIFY_SOURCE=2 -fstack-protector-strong -fstack-clash-protection \
                 -fcf-protection=full -Wformat -Wformat-security -Werror=format-security -fPIE
HARDEN_LDFLAGS = -pie -Wl,-z,relro -Wl,-z,now -Wl,-z,noexecstack
```

- 기준은 x86-64 Linux(gcc 11+, Rocky 9 기본 툴체인). `_FORTIFY_SOURCE` 는 최적화(`-O1` 이상)가 있어야 동작하고,
  `-U` 로 배포판 기본 정의와의 재정의 경고를 막는다. gcc 12+·glibc 2.35+ 이면 `=3` 으로 올린다
  (gcc 11 에서 `=3` 은 경고와 함께 `=2` 로 처리됨).
- aarch64 는 `-fcf-protection=full` 대신 `-mbranch-protection=standard`. macOS(clang·ld64)는
  `-fcf-protection`·`-z relro/now/noexecstack` 이 해당 없다.
- ASan 빌드(`-fsanitize=address`)와는 분리한다 — 테스트용·배포용 빌드 타깃을 나눈다.
- 결과물 검증: `annocheck <바이너리>` 또는 `arachne --audit --binary <바이너리>` (RHEL 계열 `annobin-annocheck`).
  FAIL 이 나오면 커밋 전 수정한다.
