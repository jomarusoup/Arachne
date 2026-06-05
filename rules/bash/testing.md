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

## 문법 검사

```bash
bash -n script.sh          # 문법 오류 검사 (실행 없음)
shellcheck script.sh       # 정적 분석
```
