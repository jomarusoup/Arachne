# Skills Archive

현재 주력 도메인(C/C++·Rust 시스템, Python, Web)이 아닌 스킬의 보관소.
삭제가 아니라 **opt-in 아카이브**다 — 내용·git 이력 모두 보존된다.

| 묶음 | 스킬 | 아카이브 사유 |
|---|---|---|
| Java/Spring | `java-coding-standards` `springboot-patterns` `springboot-security` `springboot-tdd` `springboot-verification` `jpa-patterns` | Java 백엔드 작업 중단 상태 (2026-07-17 과잉 기능 정리) |
| 네트워크 장비 | `netmiko-ssh-automation` `network-bgp-diagnostics` `network-config-validation` | 장비 운영 자동화 작업 중단 상태 (동일) |

## 복원 방법

해당 도메인 작업을 재개하면:

```bash
git mv skills/archive/<스킬>.md skills/
# skills/README.md·docs/USAGE.md 표에 행 복원 + 개수 표기 갱신
bash tests/check_index.sh   # 인덱스 일치 확인
```

> 참고: `rules/java/`는 paths frontmatter 로 Java 파일 편집 시에만 로드되므로(상시 비용 0)
> 아카이브하지 않고 그대로 둔다. `network-interface-health`는 리눅스 서버 쪽 인터페이스
> 진단이라 현역 유지.
