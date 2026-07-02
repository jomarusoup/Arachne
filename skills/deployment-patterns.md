---
name: deployment-patterns
description: 배포 설계와 운영 검증 패턴. 환경 분리, release slice, rollback, healthcheck, migration, observability를 다룬다.
triggers:
  paths: [".github/workflows/**", "**/Dockerfile"]
  keywords: ["배포", "rollback", "healthcheck", "observability", "릴리스"]
---

# Deployment Patterns

서비스를 로컬 개발에서 운영 환경으로 옮길 때 필요한 배포 기준이다.

## 언제 사용하나

- Docker/Compose에서 운영 배포로 확장할 때
- release, rollback, migration 순서를 설계할 때
- healthcheck, readiness, observability를 추가할 때
- staging과 production 환경 차이를 줄일 때

## 배포 체크리스트

- [ ] 빌드 산출물이 재현 가능하다.
- [ ] 환경변수와 secret 목록이 문서화돼 있다.
- [ ] healthcheck와 readiness check가 분리돼 있다.
- [ ] DB migration은 expand-contract 또는 rollback 전략이 있다.
- [ ] 배포 후 smoke test가 있다.
- [ ] 로그, metric, trace 중 최소 하나로 실패를 추적할 수 있다.
- [ ] rollback 조건과 담당자가 명확하다.

## Migration 순서

1. backward-compatible schema 추가
2. 애플리케이션이 새/구 schema 모두 읽도록 배포
3. backfill
4. 읽기 경로 전환
5. 오래된 컬럼/경로 제거

## Docker와 연결

- 운영 이미지는 production target만 사용한다.
- debug port와 dev volume은 운영 compose에 남기지 않는다.
- container healthcheck가 애플리케이션 readiness를 실제로 반영하는지 확인한다.
