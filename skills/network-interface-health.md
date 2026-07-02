---
name: network-interface-health
description: 라우터·스위치·Linux 호스트의 인터페이스 오류·드롭·CRC·듀플렉스 불일치·플래핑·속도 협상 이슈·카운터 추세 진단.
triggers:
  paths: []
  keywords: ["인터페이스 오류", "CRC", "플래핑", "링크 다운"]
---

# 네트워크 인터페이스 상태

물리적 링크·스위치 포트·케이블·트랜시버·듀플렉스 설정·혼잡한 인터페이스가 네트워크 증상의 원인일 때 사용한다.

## 언제 사용하나

- 호스트 또는 VLAN에 패킷 손실, 지연 스파이크, 간헐적 도달 불가 발생
- 스위치 또는 라우터 인터페이스에 CRC, 런트, 자이언트, 드롭, 리셋, 플랩 표시
- 하드웨어 교체 전에 링크 양쪽을 비교해야 할 때
- 변경 창에 전후 인터페이스 카운터 증거 필요
- 모니터링에서 `ifInErrors`, `ifOutErrors`, `ifOutDiscards` 증가 보고

## 작동 방식

인터페이스 카운터는 증거이지만 절대값보다 추세가 더 중요하다.
기준선 수집 → 측정 간격 대기 → 다시 수집 → 증가량 비교.

```text
show interfaces <interface>
show interfaces <interface> status
show logging | include <interface>|changed state|line protocol
```

Linux 호스트:

```text
ip -s link show <interface>
ethtool <interface>
ethtool -S <interface>
```

## 카운터 참조

| 카운터       | 의미                         | 일반적인 원인                                          |
| ------------ | ---------------------------- | ------------------------------------------------------ |
| CRC          | 수신 프레임 체크섬 실패      | 불량 케이블, 더러운 광섬유, 불량 옵틱, 듀플렉스 불일치 |
| input errors | 수신 측 오류 합계            | 결론 전 하위 카운터 확인                               |
| runts        | 최소 이더넷 크기 미만 프레임 | 듀플렉스 불일치, 충돌 도메인, 결함 있는 NIC            |
| giants       | 예상 MTU보다 큰 프레임       | MTU 불일치 또는 점보 프레임 경계                       |
| input drops  | 인바운드 패킷 수용 불가      | 버스트, 과부하, CPU 경로, 큐 압력                      |
| output drops | 이그레스 큐 패킷 폐기        | 혼잡, QoS 정책, 소용량 업링크                          |
| resets       | 인터페이스 하드웨어 리셋     | 플래핑, 킵얼라이브, 드라이버, 옵틱, 전원               |
| collisions   | 이더넷 충돌 카운터           | 반이중 또는 협상 불일치                                |

## 진단 흐름

### CRC 또는 입력 오류

1. 카운터가 증가 중인지 확인 (역사적 수치가 아닌지)
2. 링크 양쪽 확인. 수신 측 오류는 보통 해당 측에 도착하는 신호를 지시
3. 패치 케이블 교체 또는 광섬유·옵틱 청소/교체
4. 양쪽의 속도/듀플렉스 설정이 일치하는지 확인
5. 같은 타임스탬프 주변의 플랩 이벤트 로그 확인

### 드롭

1. 입력 드롭과 출력 드롭 분리
2. 인터페이스 속도와 용량 비교
3. QoS 정책, 큐 카운터, 링크가 과부하 업링크인지 확인
4. 큐 튜닝은 2차. 먼저 링크가 혼잡한지 확인

### 듀플렉스 및 속도

양쪽에서 지원하면 현대 이더넷 링크에서 자동 협상을 권장한다.
한쪽이 고정이어야 하면 양쪽 모두 명시적으로 설정하고 이유를 문서화한다.
한쪽 고정 속도/듀플렉스와 다른쪽 자동을 혼용하지 않는다.

```text
show interfaces <interface> | include duplex|speed
```

## 안전한 파서 예시

```python
import re
from typing import Any

HEADER_RE = re.compile(
    r"^(?P<name>\S+) is (?P<status>(?:administratively )?down|up), "
    r"line protocol is (?P<protocol>up|down)",
    re.I | re.M,
)
ERROR_RE = re.compile(r"(?P<input>\d+) input errors, (?P<crc>\d+) CRC", re.I)
DROP_RE = re.compile(r"(?P<output>\d+) output errors", re.I)
DUPLEX_RE = re.compile(r"(?P<duplex>Full|Half|Auto)-duplex,\s+(?P<speed>[^,]+)", re.I)

def parse_show_interfaces(raw: str) -> list[dict[str, Any]]:
    headers = list(HEADER_RE.finditer(raw))
    interfaces = []
    for index, header in enumerate(headers):
        end = headers[index + 1].start() if index + 1 < len(headers) else len(raw)
        block = raw[header.start():end]
        errors = ERROR_RE.search(block)
        drops = DROP_RE.search(block)
        duplex = DUPLEX_RE.search(block)
        interfaces.append({
            "name": header.group("name"),
            "status": header.group("status"),
            "protocol": header.group("protocol"),
            "duplex": duplex.group("duplex") if duplex else "unknown",
            "speed": duplex.group("speed").strip() if duplex else "unknown",
            "input_errors": int(errors.group("input")) if errors else 0,
            "crc_errors": int(errors.group("crc")) if errors else 0,
            "output_errors": int(drops.group("output")) if drops else 0,
        })
    return interfaces
```

## 안티패턴

- 기준선 저장 전에 카운터 클리어
- 링크의 한쪽만 확인
- 시간 창 없이 모든 과거 CRC를 현재 문제로 가정
- 한쪽은 자동 협상, 다른쪽은 고정 속도/듀플렉스 혼용
- 혼잡 확인 전에 출력 드롭을 케이블 문제로 취급
