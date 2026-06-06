# Syncthing 양방향 자동 동기화 (Linux ↔ macOS)

원격 Linux 서버의 `/home/Harness/Arachne`와 MacBook의 Obsidian 프로젝트 폴더를
**Syncthing**으로 양방향 자동 동기화한다. 변경된 파일은 양쪽이 온라인일 때 즉시
전파되며, 충돌 발생 시 양쪽 모두 보존된다.

## 동기화 방식 비교

| 방식                 | 트리거               | 방향                       | 충돌 처리                          | 용도                                     |
| -------------------- | -------------------- | -------------------------- | ---------------------------------- | ---------------------------------------- |
| `docs-sync.sh`       | 수동 (`pull`/`push`) | 단방향 (호출 시 결정)      | rsync timestamp 기반 덮어쓰기      | 가끔 끌어오기·올리기, 미리보기(`--dry-run`) |
| **Syncthing**        | 자동 (파일 변경 감지) | 양방향                     | `.sync-conflict-*` 파일로 양쪽 보존 | 상시 백그라운드 동기화                   |

> 두 방식은 공존 가능하다. Syncthing이 상시 동기화를 담당하고, `docs-sync.sh`는
> Syncthing 미설치 환경(또는 디버그용)에서 단발 동기화로 활용한다.

## 사전 준비

| 항목                       | 원격 (Linux)                          | 로컬 (macOS)                    |
| -------------------------- | ------------------------------------- | ------------------------------- |
| 사용자                     | `Harness` (실제 사용자)               | `jomarusoup`                    |
| 패키지 관리자              | `dnf` / `apt`                         | Homebrew                        |
| sudo 권한                  | 필요 (방화벽·systemd)                 | 불필요                          |
| 양방향 TCP 22000           | 서버에서 열기 (방화벽)                | 클라이언트 발신만 가능하면 됨   |
| `~/.ssh/authorized_keys`   | `chmod 600` 필수 (사전 등록)          | -                               |

> 원격 서버는 GUI가 없는 헤드리스 환경이라 **CLI 전용**으로 설정하고,
> Mac은 메뉴바 앱 + 브라우저 GUI를 사용한다.

---

## 1단계 — 원격 (Linux) 설치

### 1.1 패키지 설치

```bash
# RHEL/CentOS/Rocky
sudo dnf install -y syncthing

# Debian/Ubuntu
sudo apt-get install -y syncthing
```

### 1.2 방화벽 개방

Syncthing은 두 포트를 사용한다.

| 포트            | 프로토콜 | 용도                                |
| --------------- | -------- | ----------------------------------- |
| `22000`         | TCP      | 데이터 전송 (필수)                  |
| `21027`         | UDP      | 로컬 디스커버리 (멀티캐스트, 선택) |
| `8384`          | TCP      | 웹 GUI (원격은 비활성화 권장)       |

원격(공인 IP) 서버 환경에서는 22000만 열고 GUI는 닫는다.

```bash
sudo firewall-cmd --permanent --add-port=22000/tcp
sudo firewall-cmd --reload
```

### 1.3 systemd 시스템 service 활성화

> **주의**: `systemctl --user`는 SSH 세션에서 D-Bus가 없어 실패한다
> ("미디어가 없음" 오류). 시스템 서비스 형태인 `syncthing@<user>`를 사용한다.

```bash
sudo systemctl enable --now syncthing@Harness.service
sudo systemctl status syncthing@Harness.service
```

`Active: active (running)`이면 정상.

### 1.4 GUI 리스닝 주소 확인

원격에서는 GUI를 외부에 노출하지 않는다. 기본값(`127.0.0.1:8384`) 유지를 확인:

```bash
grep '<address>' ~/.local/state/syncthing/config.xml
```

`127.0.0.1:8384`이면 OK. `0.0.0.0:8384`로 잡혀 있다면 즉시 바꾼다.

### 1.5 원격 Device ID 확인

```bash
syncthing --device-id
# 예: UBH364Y-E6QZ5NV-JRCBAP2-SASYS7S-CAOMXFU-M3AR6D7-NVSAW4Q-YNRRKAR
```

이 값을 Mac에 등록할 때 쓴다.

---

## 2단계 — 로컬 (Mac) 설치

### 2.1 Homebrew로 설치

```bash
brew install --cask syncthing
```

또는 [공식 사이트](https://syncthing.net)에서 macOS 앱을 받아 설치.

### 2.2 첫 실행 및 GUI 접근

Spotlight에서 `Syncthing` 실행 → 메뉴바 아이콘이 뜬다.
브라우저에서 `http://localhost:8384` 접속.

> HTTPS로 바꾸려면 Actions → Settings → GUI → Listen Address를
> `https://127.0.0.1:8384`로 변경. 자체 서명 인증서라 브라우저 경고가 뜨지만
> localhost는 보안 차이가 없으므로 HTTP 기본값이 편하다.

### 2.3 Mac Device ID 확인

GUI 우상단 **Actions → Show ID**, 또는:

```bash
cat ~/Library/Application\ Support/Syncthing/cert.pem | \
  grep -oE 'Device ID: [A-Z0-9-]+'
```

---

## 3단계 — Device 페어링

양쪽이 서로의 Device ID를 알아야 연결된다.

### 3.1 원격 → Mac 등록 (CLI)

```bash
# 반드시 Harness 사용자로 실행 (root에서는 cert.pem 못 찾음)
su - Harness
syncthing cli config devices add \
  --device-id <Mac의 Device ID> \
  --name Mac
```

### 3.2 Mac → 원격 등록 (GUI)

1. `http://localhost:8384` 열기
2. 우하단 **Add Remote Device** 클릭
3. **Device ID** 필드에 원격 Device ID 입력
4. **Device Name**: `Prod` (식별용)
5. **Advanced** 탭 → **Addresses**:
   ```
   tcp://<원격 IP>:22000
   ```
   기본값(`dynamic`)은 NAT 뒤 디스커버리에 의존하므로 명시하는 게 안전하다.
6. Save

### 3.3 연결 확인

Mac GUI 우측 패널에 `Prod` device가 **연결됨(미사용)** 으로 뜨면 성공.
("미사용"은 아직 공유 폴더가 없다는 뜻일 뿐 정상)

---

## 4단계 — 폴더 공유

### 4.1 Mac GUI에서 폴더 추가

1. 좌측 **Add Folder** 클릭
2. **Folder Label**: `Arachne`
3. **Folder Path**:
   ```
   /Users/jomarusoup/Desktop/HOME/Life-Hack/100. Project/110. Side-Project/111. Arachne
   ```
4. **Sharing** 탭 → `Prod` 체크
5. **Advanced** 탭 → **Folder Type**: **Send & Receive** (송수신)
   > "Receive Encrypted"로 두면 원격과 타입 불일치로 동기화 실패한다.
6. Save → Folder ID가 자동 생성됨 (예: `ygpiw-w5hcx`)

### 4.2 원격에서 폴더 수락 (CLI)

Mac이 Save한 직후 원격에 pending 폴더가 생긴다. Auto-accept가 켜져 있으면
자동 수락되지만 일반적으로는 수동 수락이 필요하다.

먼저 폴더 목록 확인:

```bash
syncthing cli config folders list
# default        ← 설치 시 자동 생성된 기본 폴더
# ygpiw-w5hcx    ← Mac이 공유한 Arachne 폴더
```

폴더 설정 조회 (REST API 직접 호출):

```bash
API_KEY=$(grep -oP '(?<=<apikey>)[^<]+' ~/.local/state/syncthing/config.xml)
curl -s -H "X-API-Key: $API_KEY" \
  http://127.0.0.1:8384/rest/config/folders/<folder-id>
```

`"path"`, `"type": "sendreceive"`, `"devices"` 확인.

### 4.3 원격 폴더에 Mac device 연결

`devices` 배열에 Prod 자신만 있고 Mac이 없으면 직접 추가:

```bash
syncthing cli config folders <folder-id> devices add \
  --device-id <Mac Device ID>
```

성공 후 Mac GUI 폴더 상태가 **최신** 또는 **동기화 중**으로 바뀐다.

---

## 5단계 — `.stignore`로 동기화 범위 제한

기본 상태로 두면 `/home/Harness/Arachne` 전체(소스 코드·빌드 산출물 포함)가
Mac으로 내려온다. Obsidian 노트로는 문서만 필요하므로 화이트리스트 패턴으로
좁힌다.

### 5.1 Prod에 `.stignore` 생성

```bash
cat > /home/Harness/Arachne/.stignore << 'EOF'
// README.md와 docs/만 허용, 나머지 전부 무시
(?d)*
!/README.md
!/docs
!/docs/**
EOF
```

### 5.2 패턴 의미

| 패턴            | 의미                                              |
| --------------- | ------------------------------------------------- |
| `(?d)*`         | 모든 항목을 무시. `(?d)`는 대상에서도 삭제 허용    |
| `!/README.md`   | 루트 `README.md`는 예외 (동기화 허용)             |
| `!/docs`        | 루트 `docs/` 디렉터리는 예외                      |
| `!/docs/**`     | `docs/` 하위 모든 파일·디렉터리는 예외            |

> `!` 가 우선순위가 높다. 무시 패턴 뒤에 와도 예외가 적용된다.
> `(?d)` 접두사는 "이 패턴에 매칭되는 파일이 대상에 있으면 삭제 가능"을 뜻한다.

### 5.3 Mac 쪽 `.stignore` (선택)

Syncthing은 `.stignore` 자체를 동기화하므로 Prod에서 만들면 Mac으로도 전파된다.
양쪽 동일 정책이 자동 적용된다.

별도 정책을 원하면 Mac GUI에서 폴더 Edit → **Ignore Patterns** 탭에서 따로 작성한다.

---

## 검증

### 동기화 확인

1. Mac GUI에서 Arachne 폴더가 **최신** 상태인지 확인
2. Prod에서 `/home/Harness/Arachne/docs/` 안에 테스트 파일 생성:
   ```bash
   echo "test" > /home/Harness/Arachne/docs/sync-test.md
   ```
3. 수 초 내로 Mac 로컬 폴더에 동일 파일 등장 확인:
   ```bash
   ls -la "/Users/jomarusoup/Desktop/HOME/Life-Hack/100. Project/110. Side-Project/111. Arachne/docs/sync-test.md"
   ```
4. 반대 방향도 동일하게 검증 (Mac에서 만들고 Prod에서 확인)
5. 정리:
   ```bash
   rm /home/Harness/Arachne/docs/sync-test.md
   ```

### 충돌 시뮬레이션

양쪽이 동시에 같은 파일을 다른 내용으로 수정하면 늦게 수신한 쪽이
`<원본명>.sync-conflict-<날짜>-<시각>-<deviceID>.md` 파일로 보존한다.
어느 쪽도 데이터를 잃지 않으므로 수동 머지 후 충돌 파일을 삭제한다.

---

## 트러블슈팅

### `systemctl --user enable syncthing` 실패 — "미디어가 없음"

SSH 세션은 user systemd 인스턴스 D-Bus가 없다.
**해결**: 시스템 서비스 형태인 `syncthing@<user>.service`를 sudo로 활성화.

```bash
sudo systemctl enable --now syncthing@Harness.service
```

### SSH publickey 거부 — `authorized_keys` 권한 664

`sshd`의 `StrictModes`는 `authorized_keys` 권한이 그룹 쓰기 가능하면 거부한다.
**해결**:

```bash
chmod 700 ~/.ssh
chmod 600 ~/.ssh/authorized_keys
```

### `syncthing cli` 실행 시 `cert.pem` not found

root 또는 다른 사용자로 실행 중. Syncthing config는
`~/.local/state/syncthing/`에 사용자별로 저장된다.

**해결**: 실제 syncthing 인스턴스를 띄운 사용자(Harness)로 전환.

```bash
su - Harness
syncthing cli <command>
```

또는 `sudo`로 위임:

```bash
sudo -u Harness syncthing cli <command>
```

### Mac GUI에 "Failed to verify encryption consistency" 에러

```
error="remote expects to exchange plain data, but local data is encrypted
       (folder-type receive-encrypted)"
```

Mac 폴더가 **Receive Encrypted** 모드로 추가됨. Prod는 plain `sendreceive`라
타입 불일치.

**해결**: Mac GUI에서 폴더 Edit → **Advanced** → **Folder Type**을
**Send & Receive**로 변경 후 Save.

### `syncthing cli rest get` / `syncthing cli config ... get` 실패

해당 버전 CLI가 그 subcommand를 지원하지 않음.
**해결**: `curl`로 REST API 직접 호출.

```bash
API_KEY=$(grep -oP '(?<=<apikey>)[^<]+' ~/.local/state/syncthing/config.xml)
curl -s -H "X-API-Key: $API_KEY" http://127.0.0.1:8384/rest/<endpoint>
```

주요 endpoint:

| Endpoint                            | 용도                       |
| ----------------------------------- | -------------------------- |
| `/rest/config`                      | 전체 설정                  |
| `/rest/config/folders`              | 모든 폴더 목록             |
| `/rest/config/folders/<id>`         | 특정 폴더 상세             |
| `/rest/config/devices`              | 모든 device 목록           |
| `/rest/system/status`               | 시스템 상태 (Device ID 등) |
| `/rest/system/connections`          | 연결된 peer 목록           |

### `BSD readlink: -e` 옵션 없음 (macOS)

`arachne -c` 등에서 경고가 떠도 동작은 정상. 무시 가능.

---

## 자동 시작

### Prod

```bash
sudo systemctl is-enabled syncthing@Harness.service
# enabled ← 부팅 시 자동 시작
```

### Mac

메뉴바 Syncthing 아이콘 → **Settings → Start at Login** 체크.

---

## 운영 원칙

- 큰 파일 일괄 추가 시 LAN/공인망 대역 소모 주의 → `.stignore`로 좁히기
- 양쪽 시계가 크게 어긋나면 충돌 판정이 어색해진다 → NTP 동기화 확인
- `default` 폴더(설치 시 자동 생성)는 사용하지 않으면 GUI에서 삭제
- Syncthing은 **삭제도 동기화**한다. 한쪽에서 지운 파일은 다른 쪽도 사라진다.
  버전 관리가 필요하면 GUI에서 **File Versioning** 활성화 (Staggered, Trash Can 등)

## 관련 문서

- [`OBSIDIAN-DOCS-SYNC.md`](./OBSIDIAN-DOCS-SYNC.md) — `docs-sync.sh` 수동 동기화 CLI
- [공식 문서](https://docs.syncthing.net/) — Syncthing 전체 레퍼런스
- [REST API 레퍼런스](https://docs.syncthing.net/dev/rest.html) — `curl`로 직접 호출 시 참고
