---
name: sql-schema-versioning
description: 마이그레이션 도구 없이 개별 .sql 파일로 Oracle·PostgreSQL 스키마를 관리하는 버전 규약. V<번호>__<설명>.sql·R__<설명>.sql 명명, oracle/·postgres/ 방언 디렉터리, SCHEMA_HISTORY 적용 기록·체크섬, 적용 스크립트(미적용 버전 순차 적용·첫 실패 중단·dry-run), expand-contract, 빈 DB·기존 DB 이중 검증, 롤백 대신 전진 수정, Flyway 호환. 대상 경로 — **/sql/oracle/*.sql, **/sql/postgres/*.sql, **/apply-schema.sh. 키워드 — 스키마 버전, .sql 파일, SCHEMA_HISTORY, 체크섬, 전진 수정, Flyway 호환.
---

# SQL 스키마 버전 규약 — 도구 없는 `.sql` 관리

마이그레이션 도구 없이 `.sql` 파일로 스키마를 관리할 때 따르는 규약이다.
핵심은 세 가지다. 파일 이름이 버전을 정한다. 적용 기록은 DB 안 `SCHEMA_HISTORY`에 남긴다.
배포된 파일은 고치지 않고 새 버전으로 전진한다.

> Alembic(Python ORM) 프로젝트는 [`database-migrations`](../database-migrations/SKILL.md)를 따른다.
> 원칙(expand-contract·전진 수정·이중 검증)은 두 스킬이 같다.

## 언제 사용하나

- Pro*C·ecpg 서버처럼 ORM 없이 스키마를 `.sql` 파일로 관리하는 프로젝트
- 테이블·인덱스·제약을 추가·변경하는 `.sql` 파일을 새로 쓸 때
- 개발·스테이징·운영 DB의 스키마 상태가 서로 다른지 확인할 때
- 나중에 Flyway 같은 도구로 옮길 가능성을 열어 두고 싶을 때

### 언제 사용하지 않나

- Alembic·Flyway·Liquibase를 이미 쓰는 프로젝트 — 그 도구의 규약을 따른다
- 일회성 데이터 조회·운영 점검 SQL — 버전 대상이 아니다

## 디렉터리와 명명

```text
sql/
├── apply-schema.sh                 # 적용 스크립트 (templates/project/sql/)
├── oracle/
│   ├── V1__create_schema_history.sql
│   ├── V2__create_order.sql
│   ├── V10__add_order_status.sql
│   └── R__order_summary_view.sql
└── postgres/
    ├── V1__create_schema_history.sql
    ├── V2__create_order.sql
    ├── V10__add_order_status.sql
    └── R__order_summary_view.sql
```

| 종류 | 형식 | 용도 | 적용 시점 |
|---|---|---|---|
| 버전 파일 | `V<번호>__<설명>.sql` | 테이블·컬럼·인덱스·제약 변경 | 한 번만, 번호 순서대로 |
| 반복 파일 | `R__<설명>.sql` | 뷰·프로시저·함수·패키지 | 체크섬이 바뀔 때마다, 버전 파일 뒤에 |

- 번호는 정수다. 정렬은 숫자 기준이라 `V2`가 `V10`보다 먼저 적용된다.
- 앞자리 0은 무시한다. `V1`과 `V001`은 같은 버전이므로 함께 두면 중복으로 거부된다.
- 구분자는 밑줄 **두 개**(`__`)다. 설명은 영문·숫자·밑줄만 쓴다(`add_order_status`).
- 방언은 디렉터리로 나눈다. 같은 변경은 `oracle/`과 `postgres/`에 **같은 번호**로 둔다.
  한쪽 방언에만 필요한 변경이면 다른 쪽에는 같은 번호로 빈 파일(주석만)을 둔다.
- 규약에 맞지 않는 `.sql` 파일이 방언 디렉터리에 있으면 적용 스크립트가 거부한다.
  임시 스크립트는 방언 디렉터리 밖에 둔다.

## 적용 기록 테이블 — `SCHEMA_HISTORY`

적용한 파일마다 한 행을 남긴다. 템플릿은 이 테이블을 `V1__create_schema_history.sql`로 만든다.

Oracle:

```sql
CREATE TABLE SCHEMA_HISTORY (
    installed_rank  NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    version         VARCHAR2(50),                 -- 반복 파일은 NULL
    description     VARCHAR2(200)  NOT NULL,
    script          VARCHAR2(1000) NOT NULL,      -- 파일명
    checksum        NUMBER(10),
    applied_by      VARCHAR2(100)  NOT NULL,      -- USER
    applied_at      TIMESTAMP      DEFAULT SYSTIMESTAMP NOT NULL
);
```

PostgreSQL:

```sql
CREATE TABLE schema_history (
    installed_rank  integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    version         varchar(50),                  -- 반복 파일은 NULL
    description     varchar(200)  NOT NULL,
    script          varchar(1000) NOT NULL,       -- 파일명
    checksum        bigint,
    applied_by      varchar(100)  NOT NULL,       -- current_user
    applied_at      timestamptz   NOT NULL DEFAULT now()
);
```

- `applied_by`는 DB 접속 계정을 기록한다. 사람 이름·비밀번호는 기록하지 않는다.
- 이 테이블은 사람이 직접 고치지 않는다. 예외는 아래 "기존 DB 도입" 절차뿐이다.

## 체크섬 규칙

- 체크섬은 파일 내용 전체의 POSIX `cksum` CRC 값이다.
- 계산 전에 CR(`\r`)을 지운다. Windows에서 CRLF로 저장해도 같은 값이 나온다.
- 적용된 버전 파일의 체크섬이 기록과 다르면 적용 스크립트가 **중단**한다.
  배포된 파일을 고쳤다는 뜻이고, 환경마다 스키마가 달라진다.
- 반복 파일은 체크섬이 기록과 다를 때만 다시 적용한다.

## 적용 절차

적용 스크립트는 `templates/project/sql/apply-schema.sh`다. 프로젝트의 `sql/`로 복사해 쓴다.

적용 이력 조회 SQL은 프로젝트에 한 번 만들어 둔다. 출력은 한 줄에 `<버전 또는 R__설명> <체크섬>`이다.

```sql
-- sql/list-history.pg.sql (PostgreSQL)
SELECT COALESCE(version, 'R__' || replace(description, ' ', '_')), checksum
FROM schema_history ORDER BY installed_rank;

-- sql/list-history.ora.sql (Oracle, sqlplus)
SET PAGESIZE 0 FEEDBACK OFF HEADING OFF
SELECT NVL(version, 'R__' || REPLACE(description, ' ', '_')) || ' ' || checksum
FROM SCHEMA_HISTORY ORDER BY installed_rank;
EXIT
```

```bash
# 1. 계획 확인 (DB를 바꾸지 않는다)
export SQL_APPLIED_CMD='psql -X -At -F " " service=app -f sql/list-history.pg.sql'
bash sql/apply-schema.sh --dialect postgres --dry-run

# 2. 적용 (첫 실패에서 멈춘다)
SQL_CLIENT='psql -X -q service=app' bash sql/apply-schema.sh --dialect postgres

# 빈 DB 첫 적용 — 이력 테이블이 아직 없다
SQL_CLIENT='sqlplus -s /@APP_DB' bash sql/apply-schema.sh --dialect oracle --empty-db
```

1. 방언 디렉터리의 `V*__*.sql`을 번호 순으로 나열한다. 이름 위반·번호 중복이면 멈춘다.
2. 적용 이력을 읽는다. 출처는 `--applied-from <파일>`, `SQL_APPLIED_CMD`, `--empty-db` 중 하나다.
3. 적용된 버전의 체크섬을 대조한다. 불일치면 멈춘다.
4. 마지막 적용 버전보다 번호가 낮은 미적용 파일이 있으면 멈춘다(순서 역전).
   병합 중 번호가 겹쳤다면 늦게 들어온 쪽의 번호를 새로 올린다.
5. 미적용 버전을 하나씩 실행하고, 같은 입력 스트림 끝에서 `SCHEMA_HISTORY`에 기록한다.
   Oracle은 `WHENEVER SQLERROR EXIT FAILURE`, PostgreSQL은 `ON_ERROR_STOP`을 앞에 붙인다.
6. 실패하면 그 파일에서 멈춘다. 이력 행은 남지 않고, 이후 버전은 실행하지 않는다.

### 접속 정보

- `SQL_CLIENT`·`SQL_APPLIED_CMD` 내용은 출력하지 않는다. 그래도 명령줄에 비밀번호를 넣지 않는다.
- Oracle은 wallet(`sqlplus -s /@APP_DB`), PostgreSQL은 `service=`·`.pgpass`를 쓴다.
- `--applied-from`은 DB 없이 계획을 검토할 때 쓴다. 형식은 한 줄에 `<버전> [체크섬]`이다.

### 부분 적용 주의

- Oracle DDL은 문장마다 자동 커밋된다. 파일 중간에서 실패하면 앞 문장은 이미 반영돼 있다.
  그래서 버전 파일 하나에는 되도록 DDL 하나만 둔다.
- PostgreSQL DDL은 트랜잭션 안에서 실행할 수 있다. 파일을 `BEGIN; ... COMMIT;`으로 감싸면
  원자적으로 적용된다. 단 `CREATE INDEX CONCURRENTLY`는 트랜잭션 밖에서 별도 버전으로 둔다.

## Expand-Contract — 무중단 변경

컬럼 삭제·이름 변경·타입 변경을 한 버전에서 끝내지 않는다. 구 버전 서버가 아직 돌고 있기 때문이다.

| 단계 | 버전 파일 | 서버 코드 |
|---|---|---|
| 1. expand | 새 컬럼·테이블 추가 (nullable 또는 기본값) | 구·신 컬럼 모두 쓰기 |
| 2. backfill | 기존 행을 나눠서 채움 (배치·커밋 주기) | 신 컬럼에서 읽기 |
| 3. contract | 구 컬럼 제거·NOT NULL 부여 | 구 컬럼 참조 제거 후 배포 |

- contract 버전은 구 컬럼을 참조하는 서버가 모두 내려간 **다음 배포**에 넣는다.
- 대량 backfill은 한 트랜잭션으로 하지 않는다. 잠금 시간과 undo·WAL 사용량이 커진다.
- 운영 테이블 인덱스는 온라인으로 만든다. Oracle은 `ONLINE`, PostgreSQL은 `CONCURRENTLY`.

## 검증 — 빈 DB와 기존 DB 모두

변경마다 두 경로를 모두 확인한다. 한쪽만 통과하는 변경이 흔하다.

1. **빈 DB**: 새 컨테이너 DB에 `--empty-db`로 V1부터 끝까지 적용한다.
   전체 이력이 처음부터 재현되는지 본다.
2. **기존 DB**: 직전 배포 상태 DB(스테이징 복제·덤프 복원)에 신규 버전만 적용한다.
   기존 데이터에서 제약 위반·타입 변환 실패가 없는지 본다.
3. 두 결과의 스키마를 비교한다(PostgreSQL `pg_dump --schema-only`,
   Oracle `DBMS_METADATA.GET_DDL`). 차이가 있으면 버전 파일이 빠졌거나 수동 변경이 있었다.

## 롤백 대신 전진 수정

- 배포된 버전 파일은 수정·삭제하지 않는다. 체크섬 불일치로 다음 적용이 멈춘다.
- 잘못된 변경은 **새 버전**으로 되돌린다. 예: `V12__drop_wrong_index.sql`.
- down 스크립트는 만들지 않는다. 데이터를 지우는 되돌림은 복구할 수 없기 때문이다.
- 데이터 파괴 DDL(`DROP`·`TRUNCATE`)에는 같은 PR에 백업·복구 절차를 적는다.

## 기존 DB 도입 (기준선)

이미 운영 중인 DB에 규약을 처음 적용할 때의 절차다.

1. 현재 운영 스키마를 덤프해 `V2__baseline.sql`로 둔다. 빈 DB 재현용이다.
2. 기존 DB에는 `V1__create_schema_history.sql`만 실행한다.
3. 기존 DB의 `SCHEMA_HISTORY`에 V1·V2 행을 직접 넣는다. 체크섬은 `--dry-run` 출력 값을 쓴다.
   V2는 실행하지 않고 기록만 한다.
4. 이후 변경은 V3부터 쓴다.

## Flyway 호환

- 명명 규약(`V<번호>__<설명>.sql`, `R__<설명>.sql`)과 적용 순서는 Flyway와 같다.
- 기록 테이블 이름·체크섬 계산 방식은 다르다. 전환할 때는 Flyway `baseline`으로
  현재 최신 버전을 기준선으로 잡고, 이후 버전부터 Flyway가 적용하게 한다.
- 버전 번호에 점(`V1.1`)은 쓰지 않는다. 이 스크립트는 정수 버전만 지원한다.

## 체크리스트

- [ ] 파일명이 `V<번호>__<설명>.sql` 또는 `R__<설명>.sql`이다
- [ ] `oracle/`·`postgres/`에 같은 번호가 있다 (한쪽 전용이면 다른 쪽은 빈 파일)
- [ ] 배포된 버전 파일을 고치지 않았다
- [ ] 삭제·이름 변경은 expand-contract 단계로 나눴다
- [ ] `--dry-run` 계획을 확인했다
- [ ] 빈 DB·기존 DB 양쪽에 적용해 봤다
- [ ] 명령줄·로그에 비밀번호가 없다

## 참조

- 적용 스크립트: `templates/project/sql/apply-schema.sh` (테스트 `tests/sql_schema_versioning.bats`)
- 스킬: `embedded-sql`(Pro*C·ecpg), `postgres-patterns`, `database-migrations`(Alembic)
- 리뷰: 에이전트 `database-reviewer`의 "스키마 버전 체크"
