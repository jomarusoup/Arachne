---
paths:
  - "**/*.c"
  - "**/*.h"
---
# C 보안

> [common/security.md](../common/security.md) 를 확장한다.

## 메모리 안전성

```c
/* BAD: 경계 없는 복사 */
strcpy(buf, user_input);
sprintf(buf, user_input);

/* GOOD: 경계 제한 */
strncpy(buf, user_input, sizeof(buf) - 1);
buf[sizeof(buf) - 1] = '\0';
snprintf(buf, sizeof(buf), "%s", user_input);
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

## 정적 분석 도구

```bash
# cppcheck
cppcheck --enable=all --error-exitcode=1 src/

# AddressSanitizer
gcc -fsanitize=address,undefined -o binary src/*.c && ./binary

# Valgrind
valgrind --leak-check=full --error-exitcode=1 ./binary
```
