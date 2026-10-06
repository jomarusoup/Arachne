---
paths:
  - "**/*.sh"
  - "**/*.bash"
---
# Bash 테스팅

> [common/testing.md](../common/testing.md) 를 확장한다.

## 프레임워크

**bats-core** (Bash Automated Testing System) 사용.

## 테스트 실행

```bash
bats tests/
bats tests/install.bats
```

## bats 예시

```bash
#!/usr/bin/env bats

setup() {
    TMP_DIR=$(mktemp -d)
}

teardown() {
    rm -rf "${TMP_DIR}"
}

@test "CheckDependency: 존재하는 명령어 반환 0" {
    run CheckDependency "bash"
    [ "$status" -eq 0 ]
}

@test "CheckDependency: 없는 명령어 반환 1" {
    run CheckDependency "nonexistent_cmd_xyz"
    [ "$status" -eq 1 ]
    [[ "$output" == *"설치되어 있지 않습니다"* ]]
}

@test "install.sh: 심볼릭 링크 생성 확인" {
    export HOME="${TMP_DIR}"          # 설치 대상 홈을 격리
    run bash install.sh -i            # 무인자는 usage, 설치는 -i 필수
    [ "$status" -eq 0 ]
    [ -L "${TMP_DIR}/.claude/CLAUDE.md" ]
}
```

**단언이 조용히 통과하는 함정**: macOS 기본 bash 3.2는 마지막 줄이 아닌 `[[ ]]` 단언이 실패해도 테스트를
멈추지 않고, `!` 부정은 어느 bash 버전에서도 `set -e`에 잡히지 않는다. 그래서 로컬 통과가 CI 실패를 가릴 수 있다.
마지막이 아닌 단언은 `[ ]`, `grep -q`, 또는 명시적 `|| return 1`·`|| false`로 쓴다. 판정 정본은 CI다.

## 문법 검사

```bash
bash -n script.sh          # 문법 오류 검사 (실행 없음)
shellcheck script.sh       # 정적 분석
```
