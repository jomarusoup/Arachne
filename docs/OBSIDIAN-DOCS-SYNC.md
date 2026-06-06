# Obsidian Project Docs Sync

원격 Linux 서버의 여러 프로젝트에서 README와 Markdown 문서만 MacBook의 Obsidian Vault 아래
`프로젝트/` 디렉터리로 가져오거나, 필요할 때 다시 원격으로 올리는 방식이다. 새 프로그램을
상시 실행하지 않고 `rsync`를 사용한다.

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
