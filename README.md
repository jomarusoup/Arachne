# 🕷️ Arachne

> **Claude Code 글로벌 설정을 Git으로 버전 관리하는 dotfiles 레포**

`~/.claude/` 디렉터리를 심볼릭 링크로 이 레포와 연결합니다.
레포를 수정하면 글로벌 설정에 즉시 반영되고, `git push/pull`로 모든 머신을 동기화할 수 있습니다.

---

## 📁 디렉터리 구조

```
Arachne/
├── 📄 CLAUDE.md                    # 글로벌 지시서 진입점 (@rules/* 임포트만)
├── ⚙️  settings.template.json       # ~/.claude/settings.json 템플릿
├── 📊 statusline-command.sh         # 상태표시줄 스크립트
├── 🚀 install.sh                    # 신규 머신 설치 스크립트
│
├── 📂 rules/                        # Claude 전역 행동 규칙
│   ├── workflow.md                  # Claude/Gemini 역할 분담 · 전역 행동 규칙
│   ├── issue-workflow.md            # GitHub 이슈 처리 워크플로
│   ├── ui-layout.md                 # UI 레이아웃 기준
│   └── common/
│       ├── coding-style.md          # 언어별 주석·네이밍·포매팅 규칙
│       └── patterns.md              # 불변성·오류처리·코드 품질 체크리스트
│
├── 📂 commands/                     # 슬래시 커맨드 정의
│   ├── add.md                       # /add         — 기능 추가
│   ├── design.md                    # /design      — 설계 문서
│   ├── fix.md                       # /fix         — 버그 수정
│   ├── git.md                       # /git         — 커밋·푸시
│   ├── handoff.md                   # /handoff     — AI 전환 전 상태 저장
│   ├── issue.md                     # /issue       — GitHub 이슈 처리
│   ├── issue_utf8.md                # /issue_utf8  — 이슈 처리 (UTF-8)
│   ├── learn.md                     # /learn       — 패턴 학습
│   ├── save-session.md              # /save-session — 세션 요약 저장
│   ├── status.md                    # /status      — 프로젝트 현황 확인
│   └── verify.md                    # /verify      — 수정 후 검증
│
├── 📂 agents/                       # 서브에이전트 정의
│   ├── planner.md                   # 기능 추가 전 설계 전담
│   └── reviewer.md                  # 수정 후 코드 리뷰 전담
│
└── 📂 hooks/                        # Claude Code 이벤트 훅
    ├── session-start.sh             # SessionStart — 최근 세션 파일 안내
    ├── session-end.sh               # Stop         — 자동 스냅샷 생성
    └── pre-compact.sh               # PreCompact   — 압축 전 상태 임시 저장
```

---

## 🔗 심볼릭 링크 매핑

`install.sh` 실행 시 아래와 같이 연결됩니다.

| 레포 경로 | `~/.claude/` 경로 | 방식 |
|---|---|---|
| `CLAUDE.md` | `~/.claude/CLAUDE.md` | 심볼릭 링크 |
| `rules/` | `~/.claude/rules/` | 심볼릭 링크 |
| `commands/` | `~/.claude/commands/` | 심볼릭 링크 |
| `agents/` | `~/.claude/agents/` | 심볼릭 링크 |
| `hooks/` | `~/.claude/hooks/` | 심볼릭 링크 |
| `statusline-command.sh` | `~/.claude/statusline-command.sh` | 심볼릭 링크 |
| `settings.template.json` | `~/.claude/settings.json` | 생성 (`__HOME__` 치환) |

> `settings.json`은 절대경로가 포함되므로 심볼릭 링크 대신 치환 후 생성합니다.

---

## 🚀 설치 (신규 머신)

```bash
git clone https://github.com/jomarusoup/Arachne.git ~/Arachne
cd ~/Arachne
./install.sh
```

설치 스크립트가 하는 일:

1. 기존 `~/.claude/` 파일·디렉터리 자동 백업 (`.bak` 확장자)
2. 레포 → `~/.claude/` 심볼릭 링크 생성
3. `settings.template.json`의 `__HOME__` → 실제 홈 경로로 치환하여 `settings.json` 생성

---

## 🔄 동기화

### 📤 로컬 변경 → 레포에 반영

심볼릭 링크로 연결되어 있어 `~/.claude/` 파일 수정 = 레포 파일 수정입니다.
수정 후 커밋·푸시만 하면 됩니다.

```bash
cd ~/Arachne
git add -A
git commit -m "..."
git push
```

`settings.json`을 Claude Code 내부(UI)에서 변경한 경우, 템플릿도 함께 갱신합니다.

```bash
./install.sh --export-settings   # settings.json → settings.template.json 변환
git add settings.template.json
git commit -m "chore: update settings"
git push
```

### 📥 레포 업데이트 → 로컬 반영

```bash
cd ~/Arachne
git pull
# 심볼릭 링크 파일은 즉시 반영됨
# settings.json 변경이 포함된 경우 재생성
./install.sh
```

---

## ✏️ 규칙·커맨드·에이전트 추가

### 새 규칙 추가

```bash
# 1. 규칙 파일 작성
vi ~/Arachne/rules/new-rule.md

# 2. CLAUDE.md에 임포트 한 줄 추가
echo "@rules/new-rule.md" >> ~/Arachne/CLAUDE.md
```

### 새 슬래시 커맨드 추가

```bash
# commands/ 에 마크다운 파일 추가 → /파일명 으로 자동 등록
vi ~/Arachne/commands/my-command.md
```

### 새 에이전트 추가

```bash
# agents/ 에 마크다운 파일 추가
vi ~/Arachne/agents/my-agent.md
```

---

## 🚫 Git 추적 제외 항목

레포에는 설정 파일만 추적하며, 아래 항목은 `.gitignore`로 제외됩니다.

| 항목 | 이유 |
|---|---|
| `projects/` | 대화 기록·세션 데이터 (기기별 상이) |
| `cache/`, `sessions/`, `backups/` | 런타임 생성 파일 |
| `history.jsonl` | 대화 히스토리 |
| `plugins/` | 설치 시 자동 다운로드 |
| `.credentials.json` | API 키 등 민감 정보 |
| `usage_*.json` | 사용량 추적 파일 |
| `*.bak` | 설치 시 생성되는 백업 파일 |
