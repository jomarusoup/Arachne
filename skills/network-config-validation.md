---
name: network-config-validation
description: 라우터·스위치 설정의 배포 전 검사. 위험한 명령·중복 주소·서브넷 겹침·오래된 참조·관리 평면 위험·IOS 스타일 보안 위생 확인.
origin: community
---

# 네트워크 설정 검증

변경 창 전이나 자동화가 운영 장치를 수정하기 전에 네트워크 설정을 검토할 때 사용한다.

## 언제 사용하나

- 배포 전 Cisco IOS 또는 IOS-XE 스타일 스니펫 검토
- 스크립트나 템플릿에서 생성된 설정 감사
- 위험한 명령, 중복 IP 주소, 서브넷 겹침 탐색
- ACL, route-map, prefix-list, line 정책이 정의되지 않았는데 참조되는지 확인
- 네트워크 자동화용 경량 사전 비행 스크립트 작성

## 작동 방식

설정 검증을 완전한 파서가 아닌 계층화된 증거로 취급한다.
정규식 검사는 사전 비행 경고에 유용하지만, 최종 승인은 여전히 네트워크 엔지니어가 의도·플랫폼 문법·롤백 단계를 검토해야 한다.

검증 순서:
1. 파괴적 명령
2. 자격증명 및 관리 평면 노출
3. 중복 주소 및 겹치는 서브넷
4. ACL, route-map, prefix-list, 인터페이스에 대한 오래된 참조
5. NTP, 타임스탬프, 원격 로깅, 배너 등 운영 위생

## 위험 명령 감지

```python
import re

DANGEROUS_PATTERNS: list[tuple[re.Pattern[str], str]] = [
    (re.compile(r"\breload\b", re.I), "reload은 다운타임 유발"),
    (re.compile(r"\berase\s+(startup|nvram|flash)", re.I), "영구 저장소 삭제"),
    (re.compile(r"\bformat\b", re.I), "장치 파일시스템 포맷"),
    (re.compile(r"\bno\s+router\s+(bgp|ospf|eigrp)\b", re.I), "라우팅 프로세스 제거"),
    (re.compile(r"\bno\s+interface\s+\S+", re.I), "인터페이스 설정 제거"),
    (re.compile(r"\baaa\s+new-model\b", re.I), "인증 동작 변경"),
    (re.compile(r"\bcrypto\s+key\s+(zeroize|generate)\b", re.I), "장치 SSH 키 변경"),
]

def find_dangerous_commands(lines: list[str]) -> list[dict[str, str | int]]:
    findings = []
    for line_number, line in enumerate(lines, start=1):
        stripped = line.strip()
        for pattern, reason in DANGEROUS_PATTERNS:
            if pattern.search(stripped):
                findings.append({
                    "line": line_number,
                    "command": stripped,
                    "reason": reason,
                })
    return findings
```

## 중복 IP 및 서브넷 겹침

```python
import ipaddress
import re
from collections import Counter

IP_ADDRESS_RE = re.compile(
    r"^\s*ip address\s+"
    r"(?P<ip>\d{1,3}(?:\.\d{1,3}){3})\s+"
    r"(?P<mask>\d{1,3}(?:\.\d{1,3}){3})\b",
    re.I | re.M,
)

def extract_interfaces(config: str) -> list[dict[str, str]]:
    results = []
    current = None
    for line in config.splitlines():
        if line.startswith("interface "):
            current = line.split(maxsplit=1)[1]
            continue
        match = IP_ADDRESS_RE.match(line)
        if current and match:
            ip = match.group("ip")
            mask = match.group("mask")
            network = ipaddress.ip_interface(f"{ip}/{mask}").network
            results.append({"interface": current, "ip": ip, "network": str(network)})
    return results

def find_duplicate_ips(config: str) -> list[str]:
    ips = [entry["ip"] for entry in extract_interfaces(config)]
    counts = Counter(ips)
    return sorted(ip for ip, count in counts.items() if count > 1)
```

## 관리 평면 확인

```python
def check_vty_blocks(config: str) -> list[str]:
    issues = []
    for block in iter_blocks(config, "line vty"):
        if re.search(r"transport\s+input\s+.*telnet", block, re.I):
            issues.append("VTY가 Telnet 허용; SSH만 허용해야 함.")
        if not re.search(r"\baccess-class\s+\S+\s+in\b", block, re.I):
            issues.append("VTY 블록에 인바운드 access-class 소스 제한 없음.")
        if not re.search(r"\bexec-timeout\s+\d+\s+\d+\b", block, re.I):
            issues.append("VTY 블록에 명시적 exec-timeout 없음.")
    return issues
```

## 보안 위생 확인

```python
SECURITY_PATTERNS = [
    (re.compile(r"\bsnmp-server community\s+(public|private)\b", re.I),
     "기본 SNMP 커뮤니티 설정됨"),
    (re.compile(r"\bip ssh version 1\b", re.I),
     "SSH 버전 1 활성화"),
    (re.compile(r"\benable password\b", re.I),
     "enable password 사용 중; enable secret 사용"),
]

BEST_PRACTICE_PATTERNS = [
    (re.compile(r"\bntp server\b", re.I), "NTP 서버"),
    (re.compile(r"\bservice timestamps\b", re.I), "로그 타임스탬프"),
    (re.compile(r"\blogging\s+\S+", re.I), "로깅 대상 또는 버퍼"),
    (re.compile(r"\bbanner\s+(login|motd)\b", re.I), "로그인 배너"),
]
```

## 변경 창 사전 비행

1. 붙여넣을 정확한 스니펫에 위험 명령 검사 실행
2. 전체 후보 설정에 중복 IP 및 서브넷 겹침 검사 실행
3. 참조된 모든 ACL, route-map, prefix-list 존재 확인
4. 관리 평면 변경 전에 롤백 명령과 대역 외 접근 확인

## 안티패턴

- 정규식 검증을 장치 파서로 취급
- 드라이런 diff 없이 생성된 설정 적용
- 모니터링 요구사항으로 SNMPv2 커뮤니티 문자열 권장
- 관련 없는 섹션에 걸칠 수 있는 정규식으로 VTY 블록 확인
- 카운터/로그 읽기 대신 ACL 비활성화로 방화벽 동작 테스트
