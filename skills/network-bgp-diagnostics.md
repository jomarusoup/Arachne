---
name: network-bgp-diagnostics
description: 이웃 상태·라우트 교환·접두사 정책·AS 경로 검사·안전한 증거 수집을 위한 BGP 진단 전용 패턴.
origin: community
---

# 네트워크 BGP 진단

BGP 세션이 다운·플래핑·라우트 누락·예기치 않은 접두사 광고 상황에서 사용한다.
기본 워크플로는 읽기 전용 증거 수집이며, 정책 변경·리셋은 검토된 변경 창에서만 수행한다.

## 언제 사용하나

- BGP 이웃이 Idle, Connect, Active, OpenSent, OpenConfirm에 멈춤
- 세션이 Established이지만 예상 접두사 누락
- route-map, prefix-list, max-prefix 제한, AS 경로 정책이 라우트를 필터링할 수 있음
- BGP 변경 전후 증거 필요
- BGP 요약 출력을 파싱하는 자동화 검토

## 읽기 전용 트리아지 흐름

1. 정확한 이웃, 주소 패밀리, VRF, 로컬/원격 ASN 식별
2. 요약 상태와 마지막 리셋 이유 수집
3. 피어 소스 주소로의 도달 가능성 확인
4. 전송 실패 가정 전에 라우트 정책 참조 확인
5. 플랫폼에서 지원하는 경우 광고·수신·설치된 라우트 비교

```text
show bgp summary
show bgp neighbors <peer>
show ip route <peer>
show tcp brief | include <peer>|:179
show logging | include BGP|<peer>
show running-config | section router bgp
show ip prefix-list
show route-map
```

VRF, IPv6, VPNv4, EVPN을 사용하는 장치에는 플랫폼 특정 주소 패밀리 명령을 사용한다.

## 상태 해석

| 상태 | 우선 확인 항목 |
|---|---|
| 접두사 수와 함께 Established | 라우트 교환 정상; 정책과 테이블 선택 검사 |
| 접두사 없이 Established | 인바운드 정책, max-prefix, 광고된 라우트, AFI/SAFI 확인 |
| Active | TCP 세션 미완료; 라우팅, 소스, ACL, 피어 도달 가능성 확인 |
| Connect | TCP 연결 진행 중; 경로와 원격 리스너 확인 |
| OpenSent/OpenConfirm | TCP 작동; ASN, 인증, 타이머, 기능, 로그 확인 |
| Idle | 이웃 비활성화, 설정 누락, 정책 차단, 또는 백오프 타이머 |

## 전송 확인

```text
ping <peer> source <local-source>
traceroute <peer> source <local-source>
show ip route <peer>
show bgp neighbors <peer> | include BGP state|Last reset|Local host|Foreign host
```

피어가 루프백에서 소싱되는 경우 양방향 모두 루프백 주소로 라우팅되는지 확인한다.
진단 단축키로 ACL 또는 방화벽 정책을 비활성화하지 않는다.

## 라우트 정책 확인

```text
show bgp neighbors <peer> advertised-routes
show bgp neighbors <peer> routes
show ip prefix-list <name>
show route-map <name>
show bgp <prefix>
```

## AS 경로 및 접두사 검토

```text
show bgp regexp _65001_
show bgp regexp ^65001$
show bgp <prefix>
show bgp neighbors <peer> advertised-routes | include Network|Path|<prefix>
```

AS 경로 정규식은 주의해서 사용한다. `_65001_`은 AS 65001을 토큰으로 매칭한다.

## 파서 패턴

```python
import re
from typing import Any

BGP_SUMMARY_RE = re.compile(
    r"^(?P<neighbor>\d{1,3}(?:\.\d{1,3}){3})\s+"
    r"(?P<version>\d+)\s+"
    r"(?P<remote_as>\d+)\s+"
    r"(?P<msg_rcvd>\d+)\s+"
    r"(?P<msg_sent>\d+)\s+"
    r"(?P<table_version>\d+)\s+"
    r"(?P<input_queue>\d+)\s+"
    r"(?P<output_queue>\d+)\s+"
    r"(?P<uptime>\S+)\s+"
    r"(?P<state_or_prefixes>\S+)$",
    re.M,
)

def parse_bgp_summary(raw: str) -> list[dict[str, Any]]:
    rows = []
    for match in BGP_SUMMARY_RE.finditer(raw):
        state_or_prefixes = match.group("state_or_prefixes")
        if state_or_prefixes.isdigit():
            state = "Established"
            prefixes_received = int(state_or_prefixes)
        else:
            state = state_or_prefixes
            prefixes_received = None
        rows.append({
            "neighbor": match.group("neighbor"),
            "remote_as": int(match.group("remote_as")),
            "state": state,
            "prefixes_received": prefixes_received,
            "uptime": match.group("uptime"),
        })
    return rows
```

## 변경 창에서만 허용되는 작업

다음은 라우팅에 영향을 미치므로 자동 진단으로 제안하지 않는다:
- BGP 세션 클리어
- 이웃 인증, 타이머, 업데이트 소스, route-map, prefix-list 변경
- 추가 수신 라우트 저장 활성화
- 방화벽, ACL, 컨트롤 플레인 정책 완화

## 안티패턴

- `Active` 상태가 항상 원격 측 다운을 의미한다고 가정
- VRF, 주소 패밀리, update-source 차이 무시
- 토큰 경계 없이 광범위한 AS 경로 정규식 사용
- 마지막 리셋 이유와 로그 읽기 전에 피어 하드 리셋
- `received-routes` 출력 없음을 라우트 미도착 증거로 취급
