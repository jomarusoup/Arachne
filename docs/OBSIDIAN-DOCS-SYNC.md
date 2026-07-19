# Obsidian Project Docs Sync — `docs-sync` 설정 가이드

원격 Linux 서버의 프로젝트에서 `README.md`와 `docs/`만 골라 Obsidian Vault로 가져오거나,
반대로 Obsidian에서 고친 문서를 원격으로 올린다. 상시 데몬 없이 **호출할 때만 1회 rsync**가
돈다(rsync = remote sync, 변경된 블록만 복사).

> 자동·양방향 동기화가 필요하면 [SYNCTHING-SETUP.md](SYNCTHING-SETUP.md)를 본다. 두 방식은 공존 가능하다.
> 약어 풀이는 [GLOSSARY.md](GLOSSARY.md).

---

## 0. 먼저 이해할 것 — 어느 컴퓨터에 무엇이 있는가

`docs-sync`에서 가장 헷갈리는 지점은 "local"과 "remote"가 **컴퓨터 이름이 아니라 실행 위치 기준**이라는
점이다. 규칙은 하나뿐이다.

> **`docs-sync`를 실행하는 그 컴퓨터가 `local`이다.**
> `local_dir` = 실행하는 컴퓨터의 Obsidian Vault 경로
> `ssh_target` + `remote_dir` = SSH로 접속해 들어갈 상대편 프로젝트 경로

| | 실행하는 컴퓨터 (local) | SSH 상대편 (remote) |
| --- | --- | --- |
| 무엇이 있나 | **Obsidian Vault** | **프로젝트 git 저장소** |
| 설정 파일 위치 | **`~/.config/arachne/docs-sync.conf`** (여기 있어야 함) | 불필요 |
| 설치 필요 | `docs-sync`, `rsync`, `ssh` | `rsync`, `sshd` |
| `pull` 시 | 받는 쪽 (덮어써짐) | 주는 쪽 |
| `push` 시 | 주는 쪽 | 받는 쪽 (덮어써짐) |

```
   [ 실행하는 컴퓨터 = local ]                    [ SSH 상대편 = remote ]
   ~/Obsidian/프로젝트/Arachne      <-- pull --   /home/<user>/Arachne
   (local_dir)                      -- push -->   (ssh_target : remote_dir)
                                  ssh -p <ssh_port>
```

**중요**: `docs-sync.conf`는 Vault가 있는 컴퓨터에만 있으면 된다. Vault가 없는 서버에 설정 파일을
만들어 두면 `pull` 시 빈 디렉터리만 새로 생기고 아무 의미가 없다.

---

## 1. 설치

Vault가 있는 컴퓨터(= `docs-sync`를 실행할 컴퓨터)에서 실행한다.

```bash
arachne -i          # ~/.local/bin/docs-sync 로 등록된다
```

의존성 확인:

```bash
command -v rsync ssh docs-sync
```

macOS에 rsync가 없거나 너무 낡았으면 Homebrew로 최신 버전을 넣는다.

```bash
brew install rsync
```

---

## 2. SSH 접속을 먼저 성립시킨다

설정 파일을 쓰기 **전에** 반드시 SSH가 비밀번호 없이 붙는지 확인한다. rsync는 SSH 위에서 돌기
때문에, SSH가 안 되면 `docs-sync`도 100% 실패한다.

### 2.1 로컬(Vault 쪽)에서 키 생성 — 없을 때만

```bash
[ -f ~/.ssh/id_ed25519 ] || ssh-keygen -t ed25519 -C "obsidian-docs-sync"
```

### 2.2 공개키를 원격 서버에 등록

```bash
ssh-copy-id -p <ssh_port> <user>@<host>
# 예: ssh-copy-id -p 22 Arachne@203.0.113.10
```

`ssh-copy-id`가 없으면 수동으로:

```bash
cat ~/.ssh/id_ed25519.pub | ssh -p <ssh_port> <user>@<host> \
  'mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 700 ~/.ssh && chmod 600 ~/.ssh/authorized_keys'
```

> **권한 필수**: `~/.ssh`는 `700`, `authorized_keys`는 `600`. sshd의 `StrictModes`가
> 그룹 쓰기 가능한 파일을 거부해 publickey 인증이 조용히 실패한다.

### 2.3 원격 서버에 rsync가 있는지 확인

```bash
ssh -p <ssh_port> <user>@<host> 'command -v rsync || echo MISSING'
```

`MISSING`이면 원격에 설치한다(Rocky/RHEL: `sudo dnf install -y rsync`).

### 2.4 접속·경로 최종 확인

```bash
ssh -p <ssh_port> <user>@<host> 'ls -d /home/<user>/Arachne/docs'
```

이 명령이 경로를 출력해야 다음 단계로 간다.

---

## 3. 설정 파일 작성

### 3.1 뼈대 생성

```bash
docs-sync init          # ~/.config/arachne/docs-sync.conf 생성
```

생성된 파일은 **주석 처리된 예시 한 줄**만 들어 있다. 즉 이 상태로는 등록된 프로젝트가 0개다.
반드시 `#`를 떼고 실제 값으로 고쳐야 한다.

### 3.2 컬럼 정의 (5컬럼)

```text
name <TAB> ssh_target <TAB> ssh_port <TAB> remote_dir <TAB> local_dir
```

| 컬럼 | 의미 | 어느 컴퓨터 기준 | 예시 |
| --- | --- | --- | --- |
| `name` | `docs-sync pull <name>`에 쓰는 식별자. 공백 금지 | — | `arachne` |
| `ssh_target` | SSH 접속 대상. `user@host` 또는 `~/.ssh/config` 별칭 | 상대편 | `Arachne@203.0.113.10` |
| `ssh_port` | SSH 포트. 기본이면 `22` | 상대편 | `22` |
| `remote_dir` | 상대편 **프로젝트 루트**. `docs/`의 부모이지 `docs/` 자체가 아니다 | 상대편 | `/home/Arachne/Arachne` |
| `local_dir` | 실행하는 컴퓨터의 **Obsidian Vault 안 프로젝트 폴더**. `$HOME`·`~` 확장됨 | 실행 쪽 | `$HOME/Obsidian/프로젝트/Arachne` |

> `remote_dir`에 `/home/Arachne/Arachne/docs`처럼 `docs`까지 적으면 안 된다. 필터가
> `remote_dir` 기준 `/README.md`·`/docs/**`를 찾으므로 아무것도 안 걸린다.

### 3.3 ⚠️ 구분자는 반드시 **탭 문자**

컬럼 구분은 스페이스가 아니라 **탭(`\t`)** 이다. 에디터가 탭을 스페이스로 바꾸면 파싱이
깨지고 아래처럼 알아보기 힘든 에러가 난다.

```
mkdir: `' 디렉토리를 만들 수 없습니다: 그런 파일이나 디렉터리가 없습니다
```

> 이 에러 = "탭이 아니라 스페이스로 구분했다"는 뜻이다. 줄 전체가 `name` 하나로 읽혀
> `local_dir`이 빈 문자열이 되어 발생한다.

vim에서 안전하게 편집하려면 파일을 열고 먼저:

```vim
:set noexpandtab
```

그리고 컬럼 사이는 `Ctrl-V <Tab>`으로 실제 탭을 넣는다. 저장 후 탭이 살아있는지 검증한다.

```bash
cat -A ~/.config/arachne/docs-sync.conf | grep -v '^#'
```

컬럼 사이에 `^I`(탭)가 보여야 정상이다. 스페이스면 잘못된 것이다.

`printf`로 만들면 탭이 확실히 보장되므로 더 안전하다.

```bash
printf 'arachne\t<user>@<host>\t22\t/home/<user>/Arachne\t$HOME/Obsidian/프로젝트/Arachne\n' \
  >> ~/.config/arachne/docs-sync.conf
```

> `$HOME`은 **작은따옴표** 안에 있어야 한다. 큰따옴표를 쓰면 셸이 미리 풀어버려
> 다른 컴퓨터에서 재사용할 수 없는 절대경로가 박힌다.

### 3.4 작성 예시 — 이 서버는 양쪽 모두로 쓴다

이 저장소는 두 방향 모두에서 쓰인다. 각 컴퓨터마다 **자기 것만** 넣으면 된다.

#### (A) MacBook에서 실행 — 이 서버의 문서를 Vault로 가져오는 경우

`~/.config/arachne/docs-sync.conf` (MacBook에 위치):

```text
# docs-sync project map
# name<TAB>ssh_target<TAB>ssh_port<TAB>remote_dir<TAB>local_dir
arachne	<user>@<host>	22	/home/<user>/Arachne	$HOME/Obsidian/프로젝트/Arachne
```

이 서버 기준 실제값을 넣으면:

```text
arachne	Arachne@203.0.113.10	22	/home/Arachne/Arachne	$HOME/Obsidian/프로젝트/Arachne
```

- `<user>` → `Arachne` (이 서버의 로그인 사용자)
- `<host>` → 이 서버의 공인 IP 또는 도메인
- `remote_dir` → `/home/Arachne/Arachne` (이 저장소 루트)
- `local_dir` → MacBook Vault 안 경로

#### (B) 이 서버에서 실행 — 다른 원격 프로젝트를 이 서버 Vault로 가져오는 경우

`~/.config/arachne/docs-sync.conf` (이 서버에 위치):

```text
# name<TAB>ssh_target<TAB>ssh_port<TAB>remote_dir<TAB>local_dir
project-b	<user>@<other-host>	2222	/home/<user>/project-b	$HOME/Obsidian/프로젝트/project-b
```

> **이 서버에는 아직 Vault가 없다** (`~/Obsidian` 미생성). (B)를 쓰려면 Vault 경로를 먼저 정하고
> 만들어야 한다. Vault를 둘 생각이 없다면 이 서버의 `docs-sync.conf`는 비워 두는 게 맞다 —
> 서버는 (A)에서 **remote 역할**만 하며, remote 쪽에는 설정 파일이 필요 없다.

여러 프로젝트는 줄을 추가하면 된다. 프로젝트명을 생략하고 `docs-sync pull`을 실행하면
**모든 줄을 순회**한다.

### 3.5 SSH config 별칭으로 단순화 (선택)

`~/.ssh/config`에 별칭을 두면 `ssh_target`이 짧아진다.

```text
Host arachne-prod
    HostName 203.0.113.10
    User Arachne
    Port 22
    IdentityFile ~/.ssh/id_ed25519
```

```text
arachne	arachne-prod	22	/home/Arachne/Arachne	$HOME/Obsidian/프로젝트/Arachne
```

> 별칭에 `Port`를 적었어도 `ssh_port` 컬럼은 비울 수 없다. 값이 없으면 5컬럼 파싱이 깨지므로
> `22`를 넣어 둔다(스크립트는 `22`일 때 `-e ssh -p` 를 붙이지 않아 별칭 설정이 그대로 쓰인다).

### 3.6 구형 3컬럼 설정 호환

예전 형식도 계속 읽힌다.

```text
# name<TAB>remote_root<TAB>local_dir
arachne	Arachne@203.0.113.10:/home/Arachne/Arachne	$HOME/Obsidian/프로젝트/Arachne
```

포트를 명시할 수 없어 기본 22로 고정된다. 전환할 때는 `remote_root`를 `ssh_target`과
`remote_dir`로 쪼개고 포트 컬럼을 끼워 넣는다.

---

## 4. 설정 검증

작성 직후 반드시 이 순서로 확인한다.

```bash
# 1) 파싱 결과 확인 — local_dir 의 $HOME 이 실제 경로로 풀려야 정상
docs-sync list

# 2) 탭 구분자 확인 — 컬럼 사이에 ^I 가 보여야 정상
cat -A ~/.config/arachne/docs-sync.conf | grep -v '^#'

# 3) 실제 변경 없이 계획만 출력
docs-sync pull arachne --dry-run
```

`docs-sync list`가 아무것도 출력하지 않으면 모든 줄이 여전히 주석(`#`) 상태다.

---

## 5. 사용

```bash
docs-sync pull                    # 설정의 모든 프로젝트를 Vault로 가져오기
docs-sync pull arachne            # 특정 프로젝트만
docs-sync pull arachne --dry-run  # 미리보기
docs-sync push arachne --dry-run  # 올리기 미리보기
docs-sync push arachne            # Vault → 원격 프로젝트
```

삭제 반영은 기본 꺼져 있다. 원본에서 사라진 파일을 대상에서도 지우려면 명시한다.

```bash
docs-sync pull arachne --delete
```

> `push`는 원격 저장소의 `README.md`와 `docs/`를 덮어쓴다. 원격이 git 저장소라면 push 후
> `git status`로 의도치 않은 변경이 없는지 확인하고 커밋한다. `--delete`와 `push`를 함께 쓰면
> Vault에 없는 원격 문서가 삭제되므로 특히 조심한다.

---

## 6. 동기화 대상

포함:

- 프로젝트 루트의 `README.md`
- `docs/` 전체 (하위 디렉터리·파일 포함)

제외:

- 그 외 전부 — 소스 코드, 빌드 산출물, 바이너리, 트리에 흩어진 `*.md`, 하위 디렉터리 `README` 등

`agents/`·`commands/`·`rules/`처럼 운영용 마크다운이 많은 디렉터리는 문서 노이즈를 줄이려고
의도적으로 제외했다.

---

## 7. 동작 단계 — `docs-sync pull`이 내부적으로 하는 일

1. **설정 로드** — `~/.config/arachne/docs-sync.conf`를 탭 구분으로 파싱한다. 인수로 프로젝트명을
   주면 그 줄만, 생략하면 전체를 순회한다. `local_dir`의 `$HOME`·`~`가 실제 경로로 확장된다.
2. **원격 루트 구성** — `ssh_target`과 `remote_dir`을 합쳐 `user@host:/path` 형태를 만든다.
   `ssh_port`가 `22`가 아니면 `-e "ssh -p <port>"`를 덧붙인다.
3. **rsync 필터 적용** — 화이트리스트 순서가 중요하다. include가 exclude보다 **앞**에 와야 한다.
   - `--include=/README.md`
   - `--include=/docs/***`
   - `--exclude=*`
4. **전송** — 변경분(델타)만 복사한다. `--dry-run`이면 계획만, `--delete`면 원본에 없는 파일 삭제.
5. **방향** — `pull`은 원격→로컬, `push`는 소스/대상만 뒤바꿔 같은 필터를 적용한다.

---

## 8. 트러블슈팅

| 증상 | 원인 | 해결 |
| --- | --- | --- |
| ``mkdir: `' 디렉토리를 만들 수 없습니다`` | 컬럼을 **스페이스**로 구분함 | `cat -A`로 확인 후 탭으로 교체 (§3.3) |
| `docs-sync list`가 빈 출력 | 모든 줄이 주석 상태 | 예시 줄의 `#` 제거 |
| `[ERROR] 설정에서 프로젝트를 찾지 못했습니다` | `name` 오타 또는 해당 줄 없음 | `docs-sync list`로 실제 `name` 확인 |
| `Permission denied (publickey)` | 키 미등록 / 권한 문제 | §2.2 재실행, `chmod 700 ~/.ssh`·`600 authorized_keys` |
| `rsync: command not found` (원격) | 원격에 rsync 없음 | 원격에서 `sudo dnf install -y rsync` |
| 전송 파일이 0개 | `remote_dir`에 `docs`까지 적음 | 프로젝트 **루트**로 수정 (§3.2) |
| `Connection refused` | 포트 불일치 | `ssh_port` 컬럼과 실제 sshd 포트 대조 |
| `local_dir`에 `$HOME`이 그대로 | 파싱 실패 | `docs-sync list` 출력에서 확장 여부 확인 |

---

## 9. 운영 원칙

- 처음에는 항상 `--dry-run`으로 확인하고, 결과가 납득될 때만 실제 실행한다.
- `push`는 프로젝트 단위로만, Obsidian에서 문서를 고친 게 확실할 때만 실행한다.
- `--delete`는 양방향 모두 파괴적이다. 쓰기 전에 반드시 `--dry-run`을 먼저 건다.
- 설정 파일에는 비밀값이 없지만 서버 IP·계정이 들어간다. 저장소에 커밋하지 않는다.

## 관련 문서

- [SYNCTHING-SETUP.md](SYNCTHING-SETUP.md) — 상시 양방향 자동 동기화 (Syncthing)
- [GLOSSARY.md](GLOSSARY.md) — 약어 풀이
