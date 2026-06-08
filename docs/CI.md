---
Title: "Arachne CI 운영 가이드"
creation: 2026-06-08
modification: 2026-06-08
tags:
 - "arachne"
 - "ci"
 - "testing"
 - "github-actions"
aliases:
 - "arachne-ci-guide-uppercase"
---
MOC:: [[Arachne]]
FROM:: [[ci.md]]

# Arachne CI 운영 가이드

> 대문자 경로를 참조하는 기존 링크를 위한 호환 문서다. 최신 CI 구조, 플랫폼별 Mermaid 흐름,
> 로컬 재현, 실패 대응은 [ci.md](ci.md)를 정본으로 본다.

현재 CI는 [`.github/workflows/ci.yml`](../.github/workflows/ci.yml) 기준으로 다음 job을 실행한다.

- `verify-ubuntu`
- `verify-rocky`
- `verify-windows`
- `verify-macos`

자세한 운영 절차와 Windows 반복 실패 진단 흐름은 [ci.md](ci.md)를 참고한다.
