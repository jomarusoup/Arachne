# Obsidian Project Docs Sync — arachne 설정(수동) 방식

원격 Linux 서버의 여러 프로젝트에서 README와 Markdown 문서만 MacBook의 Obsidian Vault 아래
`프로젝트/` 디렉터리로 가져오거나, 필요할 때 다시 원격으로 올리는 방식이다. 새 프로그램을
상시 실행하지 않고 **rsync**(remote sync — 변경분만 효율적으로 복사하는 도구)를 사용한다.

## 문서 동기화 — 두 가지 방법

| | **이 문서: docs-sync (arachne 설정)** | Syncthing (자동) |
| --- | --- | --- |
| 트리거 | **수동** (`docs-sync pull/push`) | 자동 (파일 변경 시 즉시) |
| 설정 위치 | **`~/.config/arachne/docs-sync.conf`** (arachne 관리) | Syncthing GUI/설정 |
| 설치 | **`arachne -i` 하나로 `docs-sync` 등록** | 별도 데몬 설치 |
| 방향 | 호출 시 결정 (한쪽→다른쪽) | 양방향 |
| 적합 | 프로젝트마다 설정 1줄, 가끔·선택적 동기화, `--dry-run` 미리보기 | 상시 백그라운드 자동화 |

> **이 문서는 arachne에 내장된 설정 방식**이다. 한번에 자동 동기화를 세팅하려면
> [SYNCTHING-SETUP.md](SYNCTHING-SETUP.md)의 "빠른 시작"을 본다. 두 방식은 공존 가능.
> 약어 풀이는 [GLOSSARY.md](GLOSSARY.md).

## 설치

`arachne -i`를 실행하면 `docs-sync`가 `~/.local/bin/docs-sync`로 등록된다.

```bash
arachne -i
```

MacBook에서 실행할 때는 SSH 접속과 `rsync`가 가능해야 한다.

## 설정

처음 한 번 예시 설정을 만든다.

```bash
docs-sync init
```

기본 설정 파일:

```text
~/.config/arachne/docs-sync.conf
```

형식은 탭으로 구분한다. 원격 서버는 SSH 접속 대상과 포트를 명시한다.

```text
# name<TAB>ssh_target<TAB>ssh_port<TAB>remote_dir<TAB>local_dir
arachne	user@203.0.113.10	22	/home/Harness/Arachne	$HOME/Obsidian/프로젝트/Arachne
project-a	user@203.0.113.10	2222	/home/Harness/project-a	$HOME/Obsidian/프로젝트/project-a
```

즉, git remote가 아니라 MacBook에서 `user@IP:PORT`로 원격 Linux에 SSH 접속해 문서만 가져온다.
SSH config를 쓰고 있다면 `ssh_target`에는 별칭도 쓸 수 있다.

### 구형 3컬럼 설정 호환

이전 버전의 다음 형식도 계속 읽을 수 있다.

```text
# name<TAB>remote_root<TAB>local_dir
arachne	user@203.0.113.10:/home/Harness/Arachne	$HOME/Obsidian/프로젝트/Arachne
```

새 설정은 SSH 포트를 명시할 수 있고 필드 의미가 분명한 5컬럼 형식을 권장한다. 구형 설정을
전환할 때 `remote_root`를 `ssh_target`, `remote_dir`로 나누고 기본 SSH 포트 `22`를 넣는다.

```text
arachne	user@203.0.113.10	22	/home/Harness/Arachne	$HOME/Obsidian/프로젝트/Arachne
```

## 사용

먼저 변경 계획만 본다.

```bash
docs-sync pull --dry-run
docs-sync pull arachne --dry-run
```

문서를 Obsidian으로 가져온다.

```bash
docs-sync pull
```

Obsidian에서 수정한 문서를 원격 프로젝트로 올린다.

```bash
docs-sync push arachne --dry-run
docs-sync push arachne
```

삭제 반영은 기본적으로 꺼져 있다. 원본에서 사라진 파일을 대상에서도 지우려면 명시한다.

```bash
docs-sync pull arachne --delete
```

## 동작 단계 — `docs-sync pull`이 내부적으로 하는 일

`docs-sync pull arachne` 한 줄이 거치는 흐름:

1. **설정 로드** — `~/.config/arachne/docs-sync.conf`를 읽어 탭 구분 컬럼
   (`name`·`ssh_target`·`ssh_port`·`remote_dir`·`local_dir`)을 파싱한다. 인수에 프로젝트명을 주면
   그 한 줄만, 생략하면 **모든 프로젝트**를 순회한다. `local_dir`의 `$HOME`·`~`는 실제 경로로 확장된다.
2. **원격 루트 구성** — `ssh_target`(`user@host`)과 `ssh_port`로 rsync의 원격 소스
   `user@host:remote_dir/`를 만든다. SSH는 `-e "ssh -p <port>"`로 포트를 넘긴다(SSH config 별칭도 가능).
3. **rsync 필터 적용** — 문서만 가져오도록 화이트리스트 필터를 건다:
   - `--include=/README.md` (루트 README만)
   - `--include=/docs/***` (docs/ 하위 전부)
   - `--exclude=*` (그 외 전부 제외)
   순서가 중요하다 — include가 exclude보다 **앞**에 와야 살아남는다.
4. **전송** — rsync가 **변경분(델타)만** 복사한다. `--dry-run`이면 실제 변경 없이 계획만 출력하고,
   `--delete`를 주면 원본에서 사라진 파일을 대상에서도 지운다(기본은 보존).
5. **방향** — `pull`은 원격→로컬(Obsidian), `push`는 로컬→원격으로 소스/대상만 뒤바꿔 같은 필터를 적용한다.

> 핵심: **상시 데몬이 아니라 호출 시 1회 rsync**다. Syncthing(상시 양방향)과 달리 트리거가 명시적이고
> `--dry-run`으로 항상 미리 볼 수 있어, 가끔·선택적 동기화에 적합하다.

## 동기화 대상

포함:

- 프로젝트 루트의 `README.md`
- `docs/` 디렉터리 전체 (하위 디렉터리·파일 포함)

제외:

- 그 외 모든 파일 — 소스 코드, 빌드 산출물, 바이너리, 트리에 흩어진 `*.md`,
  하위 디렉터리의 `README` 등은 동기화하지 않는다.

문서 노이즈를 줄이기 위해 의도적으로 좁힌 정책이다. `agents/`·`commands/`·`rules/`
처럼 운영용 마크다운이 많은 디렉터리는 Obsidian에 가져오지 않는다.

## 운영 원칙

처음에는 `pull --dry-run`으로만 확인하고, 문제가 없을 때 실제 `pull`을 실행한다. `push`는
Obsidian에서 원격 문서를 수정하는 흐름이 확실할 때 프로젝트 단위로만 실행하는 편이 안전하다.
