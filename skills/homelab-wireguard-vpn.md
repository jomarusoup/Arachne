---
name: homelab-wireguard-vpn
description: WireGuard VPN 서버 설정·피어 설정·키 생성·분할 터널링 vs 풀 터널 라우팅·모바일·노트북에서 홈 네트워크 원격 접근.
origin: community
---

# 홈랩 WireGuard VPN

WireGuard는 빠르고 현대적인 VPN 프로토콜이다. 홈 네트워크 원격 접근에 최적의 선택 —
OpenVPN보다 설정이 간단하고 대부분의 대안보다 빠르다.

모든 설정 예시는 일반적인 케이스를 보여준다. 시스템에 적용하기 전에 각 명령을 — 특히 iptables 포워딩 규칙과 키 파일 권한을 — 검토하고, 유지보수 창에서 변경한다.

## 언제 사용하나

- Raspberry Pi, Linux 호스트, pfSense, 또는 라우터에 WireGuard 서버 설정
- WireGuard 키쌍 생성 및 피어 설정 파일 작성
- 전화기 또는 노트북에서 홈 네트워크로 원격 접근 설정
- 분할 터널링(홈 트래픽만 라우팅) vs 풀 터널(모든 트래픽 라우팅) 설명
- 연결되지 않는 WireGuard 연결 문제 해결
- 여러 클라이언트를 위한 피어 설정 생성 자동화

## WireGuard 작동 방식

```
스마트폰 (WireGuard 클라이언트)
    │
    │  암호화된 UDP 터널 (포트 51820)
    │
홈 라우터 (WireGuard 서버 — 공인 IP 또는 DDNS 필요)
    │
    홈 네트워크 (192.168.1.0/24, NAS, Pi 등)

모든 장치에 키쌍(공개 키 + 개인 키)이 있다.
서버는 각 클라이언트의 공개 키를 알고 있다.
클라이언트는 서버의 공개 키 + 엔드포인트(IP:포트)를 알고 있다.
중앙 서버나 인증 기관 없이 종단 간 암호화.
```

## 서버 설정 (Linux)

```bash
# WireGuard 설치
sudo apt update && sudo apt install wireguard -y

# 서버 키쌍 생성 — 처음부터 제한된 권한으로 파일 생성
sudo mkdir -p /etc/wireguard
sudo sh -c 'umask 077; wg genkey > /etc/wireguard/server_private.key'
sudo sh -c 'wg pubkey < /etc/wireguard/server_private.key > /etc/wireguard/server_public.key'

# 서버 설정 작성 — 실제 개인 키 값으로 치환
# 개인 키를 버전 관리에 저장하거나 공유하지 않는다
sudo tee /etc/wireguard/wg0.conf << 'EOF'
[Interface]
Address = 10.8.0.1/24
ListenPort = 51820
PrivateKey = <서버_개인키_붙여넣기>

PostUp   = iptables -A FORWARD -i wg0 -o eth0 -j ACCEPT
PostUp   = iptables -A FORWARD -i eth0 -o wg0 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
PostUp   = iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown = iptables -D FORWARD -i wg0 -o eth0 -j ACCEPT
PostDown = iptables -D FORWARD -i eth0 -o wg0 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
PostDown = iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE

[Peer]
# 전화기
PublicKey = <전화기_공개키>
AllowedIPs = 10.8.0.2/32

[Peer]
# 노트북
PublicKey = <노트북_공개키>
AllowedIPs = 10.8.0.3/32
EOF
sudo chmod 600 /etc/wireguard/wg0.conf

# IP 포워딩 활성화
echo "net.ipv4.ip_forward=1" | sudo tee /etc/sysctl.d/99-wireguard.conf
sudo sysctl --system

# WireGuard 시작 및 부팅 시 활성화
sudo wg-quick up wg0
sudo systemctl enable wg-quick@wg0
```

## 클라이언트 설정

```bash
# 각 클라이언트 장치마다 고유한 키쌍 생성
umask 077
wg genkey | tee phone_private.key | wg pubkey > phone_public.key
```

클라이언트 설정 파일:

```ini
[Interface]
PrivateKey = <클라이언트_개인키>
Address = 10.8.0.2/32

[Peer]
PublicKey = <서버_공개키>
Endpoint = your-home-ip.ddns.net:51820
AllowedIPs = 192.168.1.0/24            # 분할 터널
# AllowedIPs = 0.0.0.0/0, ::/0        # 풀 터널

PersistentKeepalive = 25
```

## 분할 터널 vs 풀 터널

```
# 분할 터널: AllowedIPs = 192.168.1.0/24
  홈 네트워크 트래픽만 VPN 통과. 인터넷은 직접 연결.
  최적: "NAS와 Pi에만 어디서든 접근하고 싶다."

# 풀 터널: AllowedIPs = 0.0.0.0/0, ::/0
  모든 트래픽이 홈 인터넷 연결 통과. Pi-hole 광고 차단 활용 가능.
  단점: 홈 업로드 속도가 병목.

# 멀티 서브넷 분할 터널:
  AllowedIPs = 192.168.10.0/24, 192.168.20.0/24, 192.168.30.0/24, 10.8.0.0/24
```

## 키 생성 및 피어 관리

```python
import subprocess

def generate_keypair() -> tuple[str, str]:
    """WireGuard 키쌍 생성. (개인키, 공개키) 반환."""
    private = subprocess.check_output(["wg", "genkey"]).decode().strip()
    public = subprocess.run(
        ["wg", "pubkey"], input=private.encode(), capture_output=True
    ).stdout.decode().strip()
    return private, public

def build_client_config(
    client_private_key: str,
    client_vpn_ip: str,
    server_public_key: str,
    server_endpoint: str,
    allowed_ips: str = "192.168.1.0/24",
    dns: str = "",
) -> str:
    dns_line = f"DNS = {dns}\n" if dns else ""
    return f"""[Interface]
PrivateKey = {client_private_key}
Address = {client_vpn_ip}/32
{dns_line}
[Peer]
PublicKey = {server_public_key}
Endpoint = {server_endpoint}
AllowedIPs = {allowed_ips}
PersistentKeepalive = 25
"""
```

## 문제 해결

```bash
# WireGuard 상태 및 마지막 핸드셰이크 확인
sudo wg show

# 연결 안 되면 확인:
# 1. UDP 포트 51820 열려 있는가?
sudo ufw status

# 2. 서버 공개 키가 클라이언트 설정과 일치하는가?
sudo wg show wg0 public-key

# 3. IP 포워딩 활성화됐는가?
cat /proc/sys/net/ipv4/ip_forward  # 1이어야 함

# WireGuard 재시작
sudo wg-quick down wg0 && sudo wg-quick up wg0
```

## 안티패턴

- 버전 관리에 개인 키 저장 — 개인 키는 비밀번호와 동일
- 영향 고려 없이 모바일에서 풀 터널 사용
- 모바일 클라이언트에 PersistentKeepalive 미설정
- 방화벽에서 포트 51820 열었지만 IP 포워딩 잊음
- 여러 클라이언트 장치에서 키쌍 공유
- 광범위한 "FORWARD ACCEPT" iptables 규칙 사용

## 모범 사례

- 클라이언트 장치마다 고유 키쌍 생성
- 모바일에는 분할 터널링 사용
- 모든 모바일 클라이언트에 `PersistentKeepalive = 25` 설정
- DDNS 사용 시 자격증명은 env 파일에 저장
- 클라이언트 설정에 Pi-hole IP를 `DNS =`로 추가
- 서버 키쌍 주기적 교체
