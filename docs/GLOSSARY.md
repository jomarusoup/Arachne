# Glossary — 약어·용어집

Arachne 문서에 나오는 줄임말을 **풀어 쓴 말(원어)** 과 함께 설명한다.
처음 보는 약어가 있으면 여기서 찾는다.

## Architecture & Harness

| 약어 | 풀어 쓴 말 | 설명 |
| --- | --- | --- |
| **SSOT** | Single Source of Truth (단일 진실 공급원) | 같은 정보를 여러 곳에 복제하지 않고 **한 곳만 정본**으로 두는 원칙. Arachne에선 `AGENTS.md`가 공통 규약의 SSOT다. Gemini는 심볼릭으로 즉시 보고, Codex는 재설치 때 병합본을 갱신한다. |
| **드리프트** | drift | 사본·인덱스·문서가 실제(코드·파일)와 시간이 지나며 **점점 어긋나는 현상**. SSOT와 자동 검사(CI)로 막는다. |
| **CLI** | Command-Line Interface (명령줄 인터페이스) | 터미널에서 명령으로 쓰는 프로그램. 여기선 Claude Code·Gemini CLI·Codex CLI. |
| **CI** | Continuous Integration (지속적 통합) | push·PR마다 서버에서 자동으로 검사(테스트·린트)를 돌리는 것. **배포(CD)가 아니다.** Arachne는 GitHub Actions로 Ubuntu·Rocky·Windows·macOS 검증을 수행한다. 상세는 [CI 운영 가이드](CI.md). |
| **CD** | Continuous Deployment (지속적 배포) | 검증된 변경을 자동으로 운영에 반영. Arachne엔 없다(심볼릭 링크 설치라 배포 대상이 없음). |
| **PR** | Pull Request | 브랜치 변경을 main에 합치기 전 리뷰를 요청하는 GitHub 단위. |
| **MCP** | Model Context Protocol | AI 도구가 외부 서버(도구·데이터)에 연결하는 프로토콜. `mcp-configs/`에 템플릿. |
| **RSC** | React Server Components | 서버에서 렌더되어 자기 JavaScript를 클라이언트로 보내지 않는 React 컴포넌트. |
| **TWS** | Tmux Workspace Manager (트뮤스 워크스페이스 매니저) | `arachne -s`(=`tws`)로 여는 대화형 tmux 세션 매니저. Claude Code 세션을 생성·접속·삭제. |
| **IPC** | Inter-Process Communication (프로세스 간 통신) | 소켓·파이프·공유 메모리 등으로 프로세스끼리 데이터를 주고받는 것. 시스템 프로그래밍의 핵심. |

## 개발 방법론 (Development Methodology)

| 약어 | 풀어 쓴 말 | 설명 |
| --- | --- | --- |
| **TDD** | Test-Driven Development (테스트 주도 개발) | **테스트를 먼저 쓰고**(실패=RED) → 통과할 최소 구현(GREEN) → 정리(REFACTOR) 순서로 개발하는 방식. |
| **RED / GREEN / REFACTOR** | — | TDD의 3단계: 실패하는 테스트 작성(RED) → 통과시키는 최소 코드(GREEN) → 중복 제거·구조 개선(REFACTOR). |
| **AAA** | Arrange-Act-Assert (준비-실행-검증) | 테스트를 세 구역으로 나눠 쓰는 구조: 조건 설정 → 동작 실행 → 결과 단언. |
| **SRP** | Single Responsibility Principle (단일 책임 원칙) | 함수·파일은 **한 가지 역할만** 맡는다. 줄 수가 아니라 역할로 분리를 판단. |
| **DTO** | Data Transfer Object (데이터 전송 객체) | 계층·경계를 넘나들 때 쓰는 순수 데이터 묶음. 입력/출력 스키마 분리에 쓴다. |
| **DI** | Dependency Injection (의존성 주입) | 객체가 필요로 하는 것을 내부에서 만들지 않고 **밖에서 넣어주는** 설계. FastAPI `Depends(get_db)`가 예. |
| **E2E** | End-to-End (종단 간) | 시스템을 사용자 관점에서 처음부터 끝까지 통째로 검증하는 테스트. 데몬·IPC 시나리오 또는 Playwright 웹 플로우. |

## 웹·API (Web & API)

| 약어 | 풀어 쓴 말 | 설명 |
| --- | --- | --- |
| **a11y** | accessibility (접근성) | "a" + 11글자 + "y". 스크린리더·키보드 등으로 **누구나 쓸 수 있게** 만드는 것. alt 텍스트·라벨·포커스 관리 등. |
| **XSS** | Cross-Site Scripting | 악성 스크립트가 페이지에 주입돼 실행되는 취약점. 출력 이스케이프·살균(sanitize)으로 방지. |
| **CORS** | Cross-Origin Resource Sharing (교차 출처 자원 공유) | 다른 도메인의 요청 허용 정책. `allow_origins=["*"]`+credentials 조합 금지. |
| **JWT** | JSON Web Token | 서명된 토큰으로 인증 상태를 담는 방식. issuer·만료·서명 알고리즘 검증 필수. |
| **RBAC** | Role-Based Access Control (역할 기반 접근 제어) | 사용자 역할(admin 등)에 따라 권한을 부여하는 인가 방식. |
| **REST** | Representational State Transfer | 리소스를 URL로, 동작을 HTTP 메서드로 표현하는 API 설계 양식. |
| **CWV / LCP** | Core Web Vitals / Largest Contentful Paint | 웹 성능 지표. LCP=가장 큰 콘텐츠가 그려지는 시간. |

## 인프라·동기화 (Infrastructure & Sync)

| 약어 | 풀어 쓴 말 | 설명 |
| --- | --- | --- |
| **SSH** | Secure Shell | 원격 서버에 암호화로 접속하는 프로토콜. docs-sync가 원격 문서를 가져올 때 사용. |
| **rsync** | remote sync | 변경분만 효율적으로 복사하는 동기화 도구. docs-sync의 엔진. |
| **MOC** | Map of Content (콘텐츠 지도) | Obsidian에서 관련 노트를 묶는 허브 노트. 문서 frontmatter의 `MOC::` 링크. |
| **frontmatter** | — | 마크다운 파일 맨 위 `--- ... ---` 사이의 메타데이터(제목·날짜·태그 등). |
| **P2P** | Peer-to-Peer (단말 간 직접) | 중앙 서버 없이 단말끼리 직접 통신하는 방식. Syncthing이 P2P로 동기화한다. |
| **BEP** | Block Exchange Protocol | Syncthing이 파일을 블록으로 쪼개 **바뀐 블록만** 주고받는 자체 동기화 프로토콜. |
| **TLS** | Transport Layer Security | 전송 구간을 암호화하는 표준. Syncthing의 Device ID는 이 TLS 인증서 지문이다. |

## Arachne Delegation Wrappers

> 정식 명령은 **`gemini-task` / `codex-task`**, `gtask` / `ctask`는 같은 스크립트의 **짧은 별칭**이다(둘 다 동작).

| 정식 이름 | 짧은 별칭 | 설명 |
| --- | --- | --- |
| **gemini-task** | `gtask` | Claude가 Gemini에 **읽기·요약·자문**을 위임하는 래퍼(`gemini -p` 감쌈). reader/advisor 레인. |
| **codex-task** | `ctask` | Claude가 Codex에 **테스트·버그 수정**을 위임하는 래퍼(`codex exec` 감쌈). tester/fixer 레인. |
| **arachne-task** | `atask` | **헤드리스 폴백 디스패처** — 역할별 순서로 CLI 실행 후보를 바꾼다. Codex/Gemini 단계는 기존 tester/fixer·reader/advisor 제약을 유지하며 중심·커밋 권한을 자동 승계하지 않는다. |

---

> 관련: [MULTI-CLI.md](MULTI-CLI.md) · [USAGE.md](USAGE.md) · [AGENTS.md](../AGENTS.md)
