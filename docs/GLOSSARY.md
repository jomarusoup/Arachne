# Glossary — 약어·용어집

이 문서는 Arachne 문서에 나오는 줄임말과 하네스 고유 용어를 **풀어 쓴 말(원어)** 과 함께 설명한다.
문서를 읽다가 처음 보는 약어나 용어를 만나면 여기서 찾는다.
다른 문서는 여기 적힌 용어를 같은 뜻으로 쓴다.

## Architecture & Harness

| 약어 | 풀어 쓴 말 | 설명 |
| --- | --- | --- |
| **SSOT** | Single Source of Truth (단일 진실 공급원) | 같은 정보를 여러 곳에 복제하지 않고 **한 곳만 정본**으로 두는 원칙. Arachne에선 `AGENTS.md`가 공통 규약의 SSOT다. Gemini는 심볼릭으로 즉시 보고, Codex는 재설치 때 병합본을 갱신한다. |
| **드리프트** | drift | 사본·인덱스·문서가 실제(코드·파일)와 시간이 지나며 **점점 어긋나는 현상**. SSOT와 자동 검사(CI)로 막는다. |
| **CLI** | Command-Line Interface (명령줄 인터페이스) | 터미널에서 명령으로 쓰는 프로그램. 하네스를 실행하는 도구는 Claude Code다. 공통 규약(`AGENTS.md`)은 Gemini CLI·Codex CLI·GitHub Copilot에도 배포한다. |
| **CI** | Continuous Integration (지속적 통합) | push·PR마다 서버에서 자동으로 검사(테스트·린트)를 돌리는 것. **배포(CD)가 아니다.** Arachne는 GitHub Actions로 Ubuntu·Rocky·Windows·macOS 검증을 수행한다. 상세는 [CI 운영 가이드](CI.md). |
| **CD** | Continuous Deployment (지속적 배포) | 검증된 변경을 자동으로 운영에 반영. Arachne엔 없다(심볼릭 링크 설치라 배포 대상이 없음). |
| **PR** | Pull Request | 브랜치 변경을 main에 합치기 전 리뷰를 요청하는 GitHub 단위. |
| **MCP** | Model Context Protocol | AI 도구가 외부 서버(도구·데이터)에 연결하는 프로토콜. `mcp-configs/`에 템플릿. |
| **RSC** | React Server Components | 서버에서 렌더되어 자기 JavaScript를 클라이언트로 보내지 않는 React 컴포넌트. |
| **TWS** | Tmux Workspace Manager (트뮤스 워크스페이스 매니저) | `arachne -s`(=`tws`)로 여는 대화형 tmux 세션 매니저. Claude Code 세션을 생성·접속·삭제. |
| **IPC** | Inter-Process Communication (프로세스 간 통신) | 소켓·파이프·공유 메모리 등으로 프로세스끼리 데이터를 주고받는 것. 시스템 프로그래밍의 핵심. |
| **git-bus** | — | `UserPromptSubmit` 훅(`git-bus-check.sh`)이 업스트림의 **새 커밋을 감지해 다음 프롬프트에 알리는** 보조 채널. 작성 CLI 판별·미푸시 로컬 커밋 감지는 없다. 기준점은 `.claude/last-seen-commit`. |
| **ADR** | Architecture Decision Record (아키텍처 결정 기록) | 중요한 설계 결정의 배경·대안·결과를 남기는 문서. `docs/decisions/`에 번호를 붙여 둔다. |
| **정본** | canonical source | 같은 내용이 여러 곳에 있을 때 기준이 되는 한 곳. 나머지는 정본을 가리키거나 정본에서 생성한다. SSOT 원칙을 파일 단위로 적용한 말이다. |
| **서브에이전트** | subagent | Claude Code가 작업 일부를 맡기는 별도 대화 인스턴스. `agents/`에 정의한 리뷰어·planner·tdd·debugger가 여기에 해당한다. |
| **PreToolUse** | — | Claude가 도구를 실행하기 직전에 도는 훅 이벤트. Arachne는 이 시점에 Bash 명령을 가드 훅으로 검사한다. |
| **가드 훅** | guard hook | PreToolUse(Bash)에 등록된 검사 훅. `hooks/guard-bash.sh`는 검사 우회를 거부하고 파괴 명령·비밀 파일 열기는 확인을 받는다. `hooks/guard-secrets.sh`는 `git commit` 직전 커밋될 줄의 비밀값·개인정보를 검사한다. 실수를 막는 장치이며 보안 경계는 아니다. |
| **permissionDecision** | — | PreToolUse 훅이 JSON으로 돌려주는 판정. `deny`는 실행을 거부하고, `ask`는 사용자 확인을 받고, `allow`는 허용한다. 아무것도 출력하지 않으면 평소 권한 흐름을 따른다. |
| **permissions.deny** | — | `settings.json`에서 특정 파일 읽기를 막는 규칙 목록. `.env`·개인키·DB 접속 파일 같은 비밀 파일 접근의 1차 경계다. 예외를 둘 수 없다. |
| **합성 데이터 표식** | synthetic data marker | 일부러 남기는 예시 값을 가드와 CI 검사에서 허용하는 표식. 한 줄은 줄 끝 `ARACHNE-ALLOW-SECRET`, 파일 전체는 앞부분 `ARACHNE-SYNTHETIC-DATA`로 표시한다. |
| **UNTRUSTED 구획** | — | 외부 로그·이슈·웹 콘텐츠를 `<<UNTRUSTED ... UNTRUSTED>>`로 감싸 지시가 아닌 데이터로만 다루는 규약. 간접 프롬프트 인젝션을 막는다. |
| **worktree** | git worktree | 한 저장소에 작업 폴더를 여러 개 두는 git 기능. 여러 세션이 동시에 작업할 때 체크아웃 충돌을 막는다. 절차는 `/worktree`에 있다. |
| **웨이브** | wave | 로드맵을 나눈 실행 단위(W0~W7). 웨이브마다 브랜치를 만들고 PR로 반영한다. 계획은 [ADR-0006](decisions/0006-roadmap-2026q4.md)에 있다. |
| **3-레인 (역사)** | 3-lane | 과거의 Claude/Codex/Gemini 협업 런타임. [ADR-0004](decisions/0004-remove-3lane-runtime.md)로 `archive/multi-cli/`에 보존·제거 — 현재는 Claude Code 단독 운용. |

## 프로젝트 키트 (Project Kit)

| 용어 | 풀어 쓴 말 | 설명 |
| --- | --- | --- |
| **프로젝트 키트** | project kit | `arachne` 명령이 사용 프로젝트 저장소 안에 복사해 넣는 자산 묶음. 검증 명령, CI 워크플로, 설계 문서 양식, 코드 골격이 들어 있다. 구조는 [ARCHITECTURE 8절](ARCHITECTURE.md)에 있다. |
| **프로필** | profile | 프로젝트 키트에서 어떤 묶음을 깔지 고르는 이름. `minimal`·`python`·`python-web`·`web`·`cpp`·`rust`·`c-system`이 있고, `arachne --init-ci --profile <이름>`으로 지정한다. 선택 결과는 `.arachne/profile`에 남는다. |
| **c-system** | — | Linux C 서버용 프로필. 로그·공유메모리 모듈(`src/log`·`src/shm`), 운영 도구(`tools/`), 설정, 운영 문서, `.sql` 적용기, 네이밍 사전을 함께 깐다. 일부 코드(robust 뮤텍스 등)는 Linux 전용이다. |
| **네이밍 사전** | naming dictionary | 프로젝트가 허용하는 약어와 금지 동의어를 적은 표(`.arachne/naming-dict.tsv`). `lib/naming-check.sh`가 이 사전으로 새로 추가·변경된 식별자를 검사해 보고한다. 규약은 `naming-dictionary` 스킬에 있다. |

## 3티어 대용량 시스템 (3-Tier High-Volume System)

| 용어 | 풀어 쓴 말 | 설명 |
| --- | --- | --- |
| **3티어** | 3-tier | Arachne가 주력으로 지원하는 시스템 형태. TypeScript 클라이언트(웹·Electron) ↔ Linux C·Rust 서버 ↔ Oracle·PostgreSQL DB의 세 층으로 이어진다. 지원 자산은 [CAPABILITY-MAP 7절](CAPABILITY-MAP.md)에 있다. |
| **Pro\*C / ecpg** | Oracle Pro\*C / Embedded SQL in C for PostgreSQL | C 코드 안에 SQL을 써서 프리컴파일하는 임베디드 SQL 도구. Pro\*C는 Oracle용(`*.pc`), ecpg는 PostgreSQL용(`*.pgc`)이다. |
| **호스트 배열** | host array | 임베디드 SQL에서 여러 행을 한 번의 SQL 실행으로 넣고 빼는 C 배열 변수. 대량 적재의 기본 수단이다. |
| **공유메모리 세그먼트 헤더** | shared memory segment header | 공유메모리 영역 맨 앞에 두는 메타데이터(매직 값·레이아웃 버전·레코드 크기·상태 플래그). 프로세스는 attach할 때마다 이 헤더를 검증한 뒤에만 쓴다. |
| **robust 뮤텍스** | robust mutex | 잠금을 쥔 프로세스가 죽어도 다음 프로세스가 그 사실을 알고 복구할 수 있는 POSIX 뮤텍스. 공유메모리 동기화에 쓴다. c-system 키트는 이 경로를 Linux에서만 빌드·검증한다. |
| **백프레셔** | backpressure | 하류가 느려졌을 때 상류의 송신·수신 속도를 늦추는 흐름 제어. 백프레셔가 끊기는 지점에는 손실 정책을 둔다. |
| **손실 정책** | data loss policy | 큐가 가득 찼을 때 데이터를 어떻게 버리거나 막을지 채널마다 정한 규칙. `data-throughput-accelerator` 스킬은 이 정책을 채널마다 명시하도록 요구한다. |
| **거래 ID** | transaction ID | 한 요청·거래를 클라이언트부터 서버 프로세스와 DB 작업까지 이어 주는 식별자. 모든 운영 로그 줄에 담기며, `tools/logtrace.sh`로 한 거래의 로그를 모아 본다. |
| **테스트 벡터** | test vector | 입력 바이트와 기대 해석 결과를 짝지은 공유 테스트 데이터. C와 TypeScript 디코더가 같은 벡터로 서로의 해석이 일치하는지 검증한다. |
| **p50 / p99 / p99.9** | percentile | 지연 시간 분포의 백분위수. p99는 요청의 99%가 그 값 안에 끝나는 경계값이다. 대용량 시스템은 평균보다 꼬리 지연(p99·p99.9)을 본다. |
| **coordinated omission** | — | 부하 도구가 응답을 기다리느라 보내야 할 요청을 미루면서 느린 구간이 측정에서 빠지는 오류. 예정 송신 시각을 기준으로 지연을 재서 피한다(`load-testing`). |
| **PoC** | Proof of Concept (개념 검증) | 선택이 실제로 통하는지 작게 만들어 측정하는 실험. 예: `templates/project/throughput-poc`. |
| **FFI** | Foreign Function Interface (외부 함수 인터페이스) | 한 언어에서 다른 언어 함수를 부르는 경계. 여기선 주로 Rust ↔ C 호출을 말한다(`c-to-rust-migration`). |

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

---

> 관련: [MULTI-CLI.md](MULTI-CLI.md) · [USAGE.md](USAGE.md) · [AGENTS.md](../AGENTS.md)
