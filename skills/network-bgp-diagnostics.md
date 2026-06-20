---
name: network-bgp-diagnostics
description: BGP 세션, route advertisement, prefix filter, next-hop, AS path, flap, convergence 문제를 진단하는 네트워크 스킬.
---

# Network BGP Diagnostics

BGP 라우팅 문제를 증거 기반으로 진단한다.

## 언제 사용하나

- BGP neighbor가 Established가 되지 않을 때
- prefix가 광고되지 않거나 수신되지 않을 때
- route flap, convergence 지연, asymmetric routing이 있을 때
- route-map, prefix-list, community 정책 변경 전후를 검증할 때

## 진단 순서

1. neighbor 상태와 uptime 확인
2. local/remote AS, source interface, password, TTL, multihop 확인
3. advertised-routes와 received-routes 비교
4. prefix-list, route-map, community 정책 확인
5. next-hop reachability 확인
6. 변경 전후 route count와 best path 변화 기록

## 명령 예시

```text
show ip bgp summary
show ip bgp neighbors <peer>
show ip bgp neighbors <peer> advertised-routes
show ip bgp neighbors <peer> received-routes
show ip route <prefix>
show ip prefix-list
show route-map
```

벤더별 명령은 다를 수 있으므로 장비 OS 문서를 우선한다.

## 안전 원칙

- 운영 라우팅 정책 변경은 승인된 change window에서만 한다.
- prefix filter 완화는 영향 범위를 계산한 뒤 수행한다.
- before/after 출력을 저장해 rollback 근거를 남긴다.
