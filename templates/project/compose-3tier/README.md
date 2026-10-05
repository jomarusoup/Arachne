# compose-3tier — 3티어 로컬 통합 환경

클라이언트(웹·Electron) → C 서버 → DB 구조를 로컬 Docker 하나로 재현한다.
기본으로는 C 모듈 테스트와 PostgreSQL만 뜨고, 무거운 구성은 프로필로 켠다.

## 구성

| 서비스 | 프로필 | 하는 일 |
|---|---|---|
| `c-build` | 기본 | `c-system/src`의 모듈(`log`·`shm`·`pipeline`·`contract`)을 Linux에서 빌드하고 단위 테스트를 돈 뒤 끝난다 |
| `postgres` | 기본 | PostgreSQL 공식 이미지. 데이터는 named volume `pg-data`, 포트는 `127.0.0.1`에만 연다 |
| `schema-pg` | 기본 | `sql/apply-schema.sh`로 `sql/postgres/`의 미적용 버전을 적용하고 끝난다 |
| `c-server` | `server` | `src/<APP_DIR>`에서 만든 서버 바이너리를 실행한다. 스키마 적용이 끝난 뒤 뜬다 |
| `oracle` | `oracle` | Oracle Free(`gvenzl/oracle-free`). 이미지가 수 GB라 필요할 때만 켠다 |
| `schema-ora` | `oracle` | 같은 이미지의 sqlplus로 `sql/oracle/`을 적용한다 |
| `jaeger` | `tracing` | TypeScript 클라이언트의 OpenTelemetry 스팬 확인. UI `127.0.0.1:16686`, OTLP `4317`·`4318` |

모든 컨테이너는 root가 아닌 사용자로 돈다.
`no-new-privileges`를 켜고, 이미지가 허용하는 곳은 `cap_drop: [ALL]`과 `read_only`도 쓴다.
비밀값은 `.env`에서만 받는다. `compose.yaml`에는 값이 없다.

## 실행

```bash
cp .env.example .env            # 비밀번호 자리표시자를 로컬 전용 값으로 바꾼다
docker compose config --quiet   # 설정 검증 (.env 값이 비면 여기서 멈춘다)

docker compose up c-build                      # C 모듈 테스트만
docker compose up -d postgres schema-pg        # DB + 스키마 적용
docker compose logs schema-pg                  # 적용 결과 확인
docker compose run --rm schema-pg              # 새 V 파일을 추가한 뒤 다시 적용 (적용된 버전은 건너뛴다)

docker compose --profile oracle up -d oracle schema-ora   # Oracle 까지
docker compose --profile tracing up -d jaeger             # 추적 UI
docker compose --profile server up -d c-server            # 서버 진입점이 생긴 뒤

docker compose down             # 정지. 데이터 볼륨은 남는다
docker compose down -v          # 볼륨까지 지운다 (DB 초기화)
```

## 경로와 서버 진입점

- `C_SRC_DIR`(기본 `../c-system/src`)와 `SQL_DIR`(기본 `../sql`)은 `compose.yaml` 기준 상대 경로다. 프로젝트 배치가 다르면 `.env`에서 바꾼다.
- C 소스는 빌드 추가 컨텍스트(`csrc`)로 들어간다. 호스트에서 만든 산출물이 섞여 와도 `make clean`이 먼저 지운다.
- `c-server`는 `src/${APP_DIR}/Makefile`의 `all`이 `${APP_NAME}` 바이너리를 만든다고 가정한다. 서버는 `APP_PORT`에서 TCP로 대기해야 healthcheck가 통과한다.
- 배포 빌드와 같은 `-g -fno-omit-frame-pointer`로 빌드해 두면 스테이징 perf 결과와 심볼이 맞는다(`remote-linux-analysis` 스킬).

## 스키마 적용 방식

`schema/apply.sh`가 `SCHEMA_HISTORY` 테이블이 있는지 먼저 본다.
없으면 빈 DB로 보고 모든 버전을 적용하고, 있으면 이력과 비교해 미적용 버전만 적용한다.
체크섬이 바뀐 배포 버전이나 번호 역전이 있으면 멈춘다. 규약은 `sql-schema-versioning` 스킬이 정본이다.

## 3티어 E2E

`/e2e`의 "3티어 시나리오"를 따른다.
compose 기동 → 스키마 적용 → Playwright(웹·Electron) → 거래 ID로 로그·추적 확인 순서다.

## 확인 상태와 주의

- `docker compose config`로 설정 병합만 검증했다. 이미지 빌드와 기동은 Docker 데몬이 있는 곳에서 확인한다.
- Oracle 이미지는 Oracle Linux 기반이다. `schema-ora`가 쓰는 `bash`·`awk`·`cksum`이 이미지에 없으면 같은 명령을 호스트의 sqlplus로 실행한다.
- ASan의 누수 검사가 컨테이너에서 실패하면 개발용 override 파일에서 `c-build`에만 `cap_add: [SYS_PTRACE]`를 준다.
- 브라우저에서 Jaeger로 직접 보내지 않는다. 같은 출처 프록시를 거친다(`distributed-tracing` 스킬).
- 이 구성은 로컬 개발용이다. 운영 배포에 그대로 쓰지 않는다.
