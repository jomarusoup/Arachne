---
name: oracle-patterns
description: Oracle 설계·운영 기준 — DBMS_XPLAN.DISPLAY_CURSOR(ALLSTATS LAST) 실행 계획 증거, 바인드 변수·바인드 피킹, ''=NULL 의미, NUMBER·DATE·TIMESTAMP WITH TIME ZONE의 C 호스트 타입 매핑, 시퀀스 vs IDENTITY, 세션 풀·DRCP, 대량 경로(배열 DML·direct-path APPEND·외부 테이블·파티션 교환), 커밋·undo. 대상 경로 — **/sql/oracle/*.sql, **/*.pc. 키워드 — Oracle, DBMS_XPLAN, 바인드 피킹, direct-path, APPEND, 파티션 교환, DRCP, ORA-01555.
---

# Oracle Patterns — 증거 기반 설계 기준

Oracle 스키마·쿼리·대량 경로를 실측 증거로 결정하는 기준이다.
Pro\*C 코드 자체(호스트 배열·스레드 컨텍스트·재접속)는 `embedded-sql`을 본다.

## 언제 활성화하나

- 느린 쿼리를 분석하거나 인덱스·힌트 추가를 결정할 때
- Oracle 컬럼 타입을 C 호스트 변수로 받을 때
- 채번 방식, 세션 풀, 대량 적재 경로를 고를 때
- Oracle ↔ PostgreSQL 이식에서 의미 차이를 점검할 때

## 실행 계획 증거 — `DISPLAY_CURSOR` + `ALLSTATS LAST`

**`EXPLAIN PLAN`은 추정이다.** 실제로 실행된 계획과 행 수를 증거로 남긴다.

```sql
SELECT /*+ GATHER_PLAN_STATISTICS */ o.id, o.amt
FROM   orders o
WHERE  o.cust_id = :cust_id AND o.ord_dt >= :from_dt;

-- 같은 세션에서 바로 이어서 (SQL*Plus는 SET SERVEROUTPUT OFF)
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR(NULL, NULL, 'ALLSTATS LAST'));
```

- `GATHER_PLAN_STATISTICS` 힌트나 세션 `STATISTICS_LEVEL = ALL`이 있어야 실측 열이 채워진다.
- 다른 세션의 문장은 `V$SQL`에서 `SQL_ID`를 찾아 `DISPLAY_CURSOR('<sql_id>', NULL, 'ALLSTATS LAST')`로 본다.
- **`E-Rows`(추정)와 `A-Rows`(실측)가 크게 어긋나는 단계가 원인 후보다.** 통계·히스토그램부터 확인한다.

```text
변경 전: TABLE ACCESS FULL ORDERS  E-Rows=12  A-Rows=18  Buffers=51200  A-Time=00:00:00.41
변경 후: INDEX RANGE SCAN IX_ORDERS_CUST_DT  A-Rows=18  Buffers=22  A-Time=00:00:00.01
근거 데이터: orders 1,200만 행 / 해당 쿼리 호출 320/min
```

개발 DB의 계획은 운영 데이터 규모가 같을 때만 증거로 쓴다.

## 바인드 변수 · 바인드 피킹

- **값은 항상 바인드한다.** 리터럴을 이어 붙이면 문장마다 하드 파스가 일어나 공유 풀 경합과 CPU가 늘고,
  SQL 인젝션 위험도 생긴다.
- **바인드 피킹:** 첫 하드 파스 때 바인드 값을 보고 계획을 정한다. 값 분포가 치우친 컬럼에서는
  첫 값에 맞춘 계획이 다른 값에 나쁠 수 있다.
- 적응형 커서 공유는 `V$SQL`의 `IS_BIND_SENSITIVE`·`IS_BIND_AWARE`로 동작 여부를 본다.
- 치우친 컬럼에는 히스토그램 통계가 필요하다. 계획이 흔들려 장애가 나면 SQL 계획 베이스라인으로 고정한다.
- 바인드 타입은 컬럼 타입과 맞춘다. `VARCHAR2` 컬럼에 숫자를 바인드하면 암묵 변환으로 인덱스를 못 쓴다.

## `''` = NULL

**Oracle은 길이 0인 문자열을 NULL로 저장하고 비교한다.**

- `WHERE memo = ''`는 어떤 행도 반환하지 않는다. `WHERE memo IS NULL`로 쓴다.
- `NOT NULL` 컬럼에 `''`를 넣으면 ORA-01400이 난다.
- `LENGTH('')`는 0이 아니라 NULL이다. `'A' || NULL`은 `'A'`다.
- Pro\*C에서 `VARCHAR` `.len = 0`을 바인드하면 NULL이 들어간다.
- PostgreSQL은 `''`와 NULL을 구분한다. 이식할 때는 "빈 값"의 업무 의미를 하나로 정하고 양쪽 데이터를 정규화한다.

## 타입 → C 호스트 타입 매핑

| Oracle 타입 | C 호스트 타입 | 주의 |
|---|---|---|
| `NUMBER(p,0)`, p ≤ 9 | `int` | |
| `NUMBER(p,0)`, p ≤ 18 | `long long`(`int64`) | `int`로 받으면 오버플로(ORA-01455·절단) |
| `NUMBER(p,s)` 금액 | 정수 스케일(`long long` × 10^s) 또는 `char[]` | `double` 금지 — 십진 오차 |
| `NUMBER`(정밀도 없음) | `char[42]` | 최대 38자리 + 부호·소수점 |
| `VARCHAR2(n)` | `char[n+1]` 또는 `VARCHAR v[n]` | 문자 단위 길이면 바이트 수 = n × 최대 문자 바이트 |
| `DATE` | `char[20]` + `TO_CHAR` 형식 고정 | 초 단위 시각 포함, 시간대 없음 |
| `TIMESTAMP(6)` | `char[27]` + `TO_CHAR(..., 'FF6')` | 마이크로초 |
| `TIMESTAMP WITH TIME ZONE` | UTC로 변환한 문자열 | 오프셋·지역명을 C에서 직접 다루지 않는다 |

- **날짜는 형식을 명시해 변환한다.** `NLS_DATE_FORMAT`에 기대지 않고 `TO_CHAR(dt, 'YYYY-MM-DD HH24:MI:SS')`로 받는다.
- 세션 시작 때 `ALTER SESSION`으로 `NLS_NUMERIC_CHARACTERS`·`TIME_ZONE`을 고정하면 클라이언트 환경 차이를 없앤다.
- 시간대 값은 `SYS_EXTRACT_UTC(ts)`나 `ts AT TIME ZONE 'UTC'`로 UTC로 바꿔 넘긴다.

```sql
SELECT TO_CHAR(SYS_EXTRACT_UTC(evt_ts), 'YYYY-MM-DD"T"HH24:MI:SS.FF6"Z"') FROM events WHERE id = :evt_id;
```

## 시퀀스 vs IDENTITY

| 방식 | 쓰는 경우 |
|---|---|
| `GENERATED ALWAYS AS IDENTITY` (12c+) | 테이블 하나의 대리 키 — 기본 권장 |
| 독립 시퀀스 | 여러 테이블이 번호를 공유하거나, 삽입 전에 번호가 필요할 때 |

- 두 방식 모두 내부적으로 시퀀스다. **대량 삽입에서는 `CACHE`를 키운다**(기본 20 → 1,000 이상).
- 번호에는 빈틈이 생긴다(롤백·캐시 유실·인스턴스 재시작). 빈틈 없는 번호가 업무 요건이면 별도 채번 테이블을 쓴다.
- RAC의 `ORDER` 옵션은 노드 간 동기화 비용이 크다. 순서가 업무 요건일 때만 켠다.
- 삽입한 키는 `INSERT ... RETURNING id INTO :new_id`로 받는다. 다시 조회하지 않는다.

## 세션 풀 · DRCP

**접속 생성은 비싸다.** 요청마다 접속하지 않는다.

| 구조 | 선택 |
|---|---|
| 장수명 멀티스레드 서버 | 스레드별 전용 연결(`embedded-sql` 컨텍스트) 또는 Pro\*C `CPOOL=YES` 연결 풀 |
| 짧게 붙었다 끊는 프로세스가 많음 | DRCP — 접속 문자열에 `(SERVER=POOLED)` |
| 프로세스 수 × 연결 수가 `PROCESSES`·`SESSIONS` 한도에 가까움 | 풀 크기 축소 또는 DRCP |

- DRCP는 DBA가 `DBMS_CONNECTION_POOL.START_POOL`로 풀을 켜야 동작한다.
- DRCP 세션을 반납하면 세션 상태(패키지 변수, `ALTER SESSION` 설정, 임시 테이블)가 다음 사용자에게
  남지 않는다고 가정한다. 매 대여 때 필요한 세션 설정을 다시 적용한다.
- 풀 크기는 `동시 활성 작업 수 + 여유`로 정하고 대기 시간 상한을 둔다.

## 대량 경로

| 경로 | 쓰는 경우 | 핵심 주의 |
|---|---|---|
| 배열 DML(Pro\*C `FOR :n`) | 애플리케이션이 행을 만들어 넣는 상시 경로 | 부분 실패 처리(`embedded-sql`) |
| direct-path `INSERT /*+ APPEND */ ... SELECT` | 테이블 → 테이블 대량 복사·적재 | 테이블 배타 잠금, 아래 주의 |
| `INSERT /*+ APPEND_VALUES */` + 배열 바인드 | 배열 DML을 direct-path로 | 같은 주의 + 배치가 작으면 공간 낭비 |
| 외부 테이블(`ORGANIZATION EXTERNAL`) | 서버 파일을 SQL로 읽어 적재 | 파일 경로는 `DIRECTORY` 객체 권한으로 제한 |
| 파티션 교환 | 하루·한 달 단위 일괄 교체 | 전역 인덱스·검증 옵션 |

### direct-path(`APPEND`) 주의

- 데이터를 HWM 위에 바로 써서 undo가 거의 없고 빠르다. 대신 **테이블에 배타 잠금(TM X)을 걸어 다른 DML을 막는다.**
- 같은 트랜잭션에서 커밋 전에 그 테이블을 읽거나 고치면 ORA-12838이 난다. 적재 직후 커밋한다.
- HWM 아래 빈 공간은 재사용하지 않는다. 작은 배치를 자주 넣으면 세그먼트만 커진다.
- 활성 트리거나 참조 무결성(FK)이 있으면 **조용히 일반 경로로 바뀐다.** 계획의 `LOAD AS SELECT` 단계로 확인한다.
- `NOLOGGING`을 함께 쓰면 redo가 줄지만 그 데이터는 미디어 복구가 안 된다. 적재 후 백업을 계획에 넣는다.

### 외부 테이블 → 최종 테이블

```sql
CREATE TABLE orders_ext (id NUMBER, amt NUMBER(15,2), ord_dt VARCHAR2(19))
ORGANIZATION EXTERNAL (
    TYPE ORACLE_LOADER DEFAULT DIRECTORY load_dir
    ACCESS PARAMETERS (RECORDS DELIMITED BY NEWLINE FIELDS TERMINATED BY ',' MISSING FIELD VALUES ARE NULL)
    LOCATION ('orders_20261005.csv'))
REJECT LIMIT 0;

INSERT /*+ APPEND */ INTO orders (id, amt, ord_dt)
SELECT id, amt, TO_DATE(ord_dt, 'YYYY-MM-DD HH24:MI:SS') FROM orders_ext;
COMMIT;
```

### 파티션 교환

같은 구조의 스테이징 테이블에 적재하고 인덱스까지 만든 뒤, 파티션과 **메타데이터만 맞바꾼다.**

```sql
ALTER TABLE orders EXCHANGE PARTITION p_20261005 WITH TABLE orders_stage
    INCLUDING INDEXES WITHOUT VALIDATION UPDATE GLOBAL INDEXES;
```

- `WITHOUT VALIDATION`은 행이 파티션 범위에 맞는지 검사하지 않는다. 적재 단계에서 범위를 보장한 경우에만 쓴다.
- `UPDATE GLOBAL INDEXES`가 없으면 전역 인덱스가 `UNUSABLE`이 된다. 교환 후 인덱스 상태를 확인한다.
- 스테이징 테이블의 컬럼 순서·타입·제약·로컬 인덱스 구성이 파티션과 같아야 한다.

## 커밋 · undo

- **커밋 주기는 측정으로 정한다.** 너무 잦으면 `log file sync` 대기가, 너무 드물면 undo·락이 커진다.
- 한 트랜잭션이 너무 크면 undo 테이블스페이스가 고갈된다(ORA-30036). 재시작 가능한 배치로 나눈다.
- **ORA-01555(snapshot too old):** 긴 조회가 읽는 동안 undo가 덮어써지면 난다. 같은 테이블을 고치며
  열린 커서로 계속 FETCH하고 중간 커밋하면 위험이 커진다. 키 범위로 배치를 나눈다.
- `UNDO_RETENTION`은 가장 긴 조회 시간보다 크게 잡는다. 보장이 필요하면 `RETENTION GUARANTEE`를 검토한다.
- 커밋 중 연결이 끊기면 결과를 알 수 없다. 업무 키로 반영 여부를 확인한 뒤 재실행한다(`embedded-sql` 재접속).

## 참조

- 스킬: `embedded-sql`(Pro\*C·ecpg), `postgres-patterns`(PG 대응), `sql-schema-versioning`(`.sql` 버전 규약),
  `data-throughput-accelerator`(처리량 측정)
- 리뷰: 에이전트 `database-reviewer`, 커맨드 `/database-review`
