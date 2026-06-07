---
Title: "[bug] Claude settings 재설치가 사용자 설정을 파괴적으로 교체함"
creation: 2026-06-07
modification: 2026-06-07
tags:
 - "arachne"
 - "workflow"
 - "issue"
 - "severity/high"
aliases:
 - "settings-destructive-reinstall"
---
MOC:: [[Arachne]]
FROM:: [[2026-06-07-workflow-audit]]

# [bug] Claude settings 재설치가 사용자 설정을 파괴적으로 교체함

- **작성일**: 2026-06-07
- **심각도**: HIGH
- **영역**: `install.sh:185-200`
- **상태**: 해결됨 — 1342d21 (settings 차이 경고 + .bak·arachne -e 안내). task [[2026-06-07-install-update-safety]]

## 문제

`install_claude`는 기존 `~/.claude/settings.json`을 `.bak`으로 복사한 뒤
`settings.template.json`으로 새 파일을 생성한다. 기존 JSON과 구조 병합하지 않는다.

```bash
cp "$settings_dst" "$settings_dst.bak"
sed "s|__HOME__|$HOME|g" settings.template.json > "$settings_dst"
```

## 재현

기존 설정:

```json
{"customUserSetting": true}
```

`install.sh -i --target claude` 실행 후 활성 `settings.json`에서는 해당 키가 사라지고
백업 파일에만 남는다.

## 영향

- 사용자 MCP 서버, 권한, 플러그인, 모델, UI 설정이 비활성화될 수 있다.
- `arachne -u`도 재설치를 호출하므로 단순 업데이트가 설정 손실을 유발한다.
- 백업은 복구 수단일 뿐 정상적인 설정 공존을 제공하지 않는다.
- 반복 설치 시 `.bak`도 최신 직전 파일로 덮여 오래된 사용자 설정 복구가 어려워진다.

## 원인

Arachne 소유 설정과 사용자 소유 설정의 경계가 정의되지 않았다. 템플릿 전체를 정본으로
취급하지만 문서상으로는 기존 설정 보존을 기대하게 한다.

## 수정 방향

1. JSON 파서를 사용해 구조적으로 병합한다.
2. Arachne가 소유하는 키를 명시한다.
   - hooks의 특정 command
   - Arachne 명령 permission
   - 선택적 statusLine
3. 사용자 배열과 객체는 기본적으로 보존한다.
4. 충돌 시 `--force` 또는 대화형 선택 없이 조용히 덮어쓰지 않는다.
5. 쓰기 전 JSON 검증과 원자적 rename을 사용한다.
6. 백업 파일은 timestamp 또는 제한된 rotation을 사용한다.

## 회귀 테스트

- 사용자 임의 키 보존
- 기존 MCP 설정 보존
- Arachne 훅은 중복 없이 갱신
- 재실행 멱등성
- 잘못된 기존 JSON이면 원본을 보존하고 실패
- 중간 실패 시 활성 설정이 손상되지 않음

## 완료 조건

- 재설치와 업데이트가 사용자 설정을 제거하지 않는다.
- Arachne 소유 설정만 예측 가능하게 추가·갱신된다.
- 병합 결과가 유효한 JSON이며 rollback 가능하다.
