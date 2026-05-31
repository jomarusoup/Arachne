---
name: git-flow
description: Harness 브랜치 전략·커밋 컨벤션·PR 워크플로. 커밋 형식, 브랜치 네이밍, PR 생성 절차.
origin: Harness
---

# Git 워크플로

## 언제 사용하나

- 브랜치 전략 결정 시
- 커밋 메시지 작성 시
- PR 생성·리뷰 시
- 충돌 해결 시

---

## 브랜치 전략 — GitHub Flow

```
main (보호됨, 항상 빌드·테스트 통과 상태)
  │
  ├── feat/ipc-socket-timeout   → PR → main
  ├── fix/zombie-process-leak   → PR → main
  └── refactor/conn-module      → PR → main
```

## 브랜치 네이밍

```
feat/<기능명>      feat/daemon-watchdog
fix/<버그명>       fix/null-ptr-deref
refactor/<대상>    refactor/ipc-layer
docs/<대상>        docs/api-reference
chore/<작업>       chore/update-deps
```

## 커밋 메시지 형식

```
<type>: <설명>

<선택적 본문 — 왜(Why) 중심으로>
```

### 타입

| 타입 | 의미 | 예시 |
|---|---|---|
| `feat` | 신규 기능 | `feat: epoll 기반 이벤트 루프 추가` |
| `fix` | 버그 수정 | `fix: fork() 후 좀비 프로세스 누수 수정` |
| `refactor` | 동작 변화 없는 정리 | `refactor: ipc_client 모듈 분리` |
| `docs` | 문서 수정 | `docs: README 설치 절차 업데이트` |
| `test` | 테스트 추가·수정 | `test: ConnCreate NULL 입력 케이스 추가` |
| `chore` | 빌드·설정 변경 | `chore: CMakeLists 최소 버전 상향` |
| `perf` | 성능 개선 | `perf: 소켓 버퍼 크기 최적화` |
| `style` | 포맷·스타일 | `style: clang-format 적용` |

## PR 워크플로

```bash
# 1. 브랜치 생성
git checkout -b feat/feature-name

# 2. 개발·커밋
git add [파일들]
git commit -m "feat: 기능 설명"

# 3. 최신 main 반영
git fetch origin
git rebase origin/main

# 4. 푸시
git push -u origin feat/feature-name

# 5. PR 생성
gh pr create --title "feat: 기능 설명" --body "..."
```

## 충돌 해결

```bash
# 리베이스 중 충돌 시
git status                    # 충돌 파일 확인
# 파일 편집 후 충돌 마커 제거
git add [충돌 해결된 파일]
git rebase --continue

# 리베이스 취소
git rebase --abort
```

## 유용한 명령

```bash
git log --oneline -10           # 최근 커밋 확인
git diff HEAD~1                 # 마지막 커밋 변경사항
git stash                       # 임시 저장
git stash pop                   # 복원
git cherry-pick <hash>          # 특정 커밋 적용
```
