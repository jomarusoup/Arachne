---
paths:
  - "**/*.sh"
  - "**/*.bash"
---
# Bash 보안

> [common/security.md](../common/security.md) 를 확장한다.

## 변수 따옴표

```bash
/* BAD: 단어 분리·글로빙 취약 */
rm $user_file
ls $dir

/* GOOD: 항상 따옴표 감싸기 */
rm "${user_file}"
ls "${dir}"
```

## 커맨드 인젝션 방지

```bash
/* BAD: eval 사용 */
eval "echo ${user_input}"

/* BAD: 변수를 명령어로 직접 사용 */
$user_command

/* GOOD: 허용 목록 검증 */
case "${action}" in
    start|stop|restart) systemctl "${action}" myservice ;;
    *) echo "[ERROR] 허용되지 않은 액션: ${action}" >&2; exit 1 ;;
esac
```

## 임시 파일

```bash
/* BAD: 예측 가능한 파일명 */
TMP=/tmp/myscript.tmp

/* GOOD: mktemp 사용 */
TMP=$(mktemp)
trap 'rm -f "${TMP}"' EXIT
```

## 권한 검사

```bash
/* root 권한 필요 시 명시적 검사 */
if [ "$(id -u)" -ne 0 ]; then
    echo "[ERROR] root 권한이 필요합니다" >&2
    exit 1
fi
```

## 정적 분석

```bash
shellcheck --severity=warning script.sh
```
