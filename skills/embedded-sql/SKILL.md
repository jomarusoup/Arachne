---
name: embedded-sql
description: 임베디드 SQL 프로그래밍 — Oracle Pro*C(*.pc)와 PostgreSQL ecpg(*.pgc). 호스트/인디케이터 변수·SQLCA 에러 처리·커서·동적 SQL·프리컴파일 빌드 통합·트랜잭션 패턴, 호스트 배열 대량 처리·멀티스레드 컨텍스트·재접속 정책·커밋 주기. 대상 경로 — **/*.pc, **/*.pgc. 키워드 — Pro*C, ecpg, 임베디드 SQL, SQLCA, 호스트 변수, 호스트 배열, 프리컴파일, CONTEXT ALLOCATE, 재접속.
---

# 임베디드 SQL (Pro*C · ecpg)

C 소스에 `EXEC SQL` 구문을 넣으면 프리컴파일러가 DB 라이브러리 호출로 바꾼다.
이 스킬은 Oracle **Pro\*C**(`*.pc`)와 PostgreSQL **ecpg**(`*.pgc`)를 공통 개념과 차이표로 함께 다룬다.

## 언제 사용하나

- `*.pc`·`*.pgc`를 작성·리뷰하거나 호스트 변수·커서·동적 SQL·호스트 배열을 설계할 때
- 에러 처리·트랜잭션 경계·재접속 정책을 구현하거나, 멀티스레드 서버에서 연결을 나눠 쓸 때
- 프리컴파일을 빌드에 넣거나 Oracle ↔ PostgreSQL 코드를 이식할 때

일반 C는 `rules/c/*`, 드라이버 API는 `postgres-patterns`·`oracle-patterns`, 스키마는 `sql-schema-versioning`을 본다.

## 공통 개념

### 파이프라인

```
소스(.pc/.pgc) ── 프리컴파일러(proc/ecpg) ──▶ 순수 C(.c) ── cc ──▶ 실행 파일
```

- **`.pc`·`.pgc`가 소스다.** 생성된 `.c`는 산출물이므로 커밋하지 않고 `.gitignore`에 등록한다.
- 헤더 주석·리뷰·수정은 모두 `.pc`·`.pgc`에 한다. 프리컴파일러는 `EXEC SQL` 블록만 해석한다.

### 호스트 변수 · 인디케이터 변수

C 변수는 DECLARE SECTION에 선언하고 SQL 안에서 `:이름`으로 참조한다.
**NULL을 판별하는 수단은 인디케이터 변수뿐이다.** 인디케이터 없이 NULL을 읽으면
Pro\*C는 ORA-01405를 내고, ecpg는 오류 또는 쓰레기 값을 남긴다.

```c
EXEC SQL BEGIN DECLARE SECTION;
    int     emp_id;
    char    emp_name[64];
    double  salary;
    short   salary_ind;         /* -1=NULL, 0=정상, >0=절단 */
EXEC SQL END DECLARE SECTION;

EXEC SQL SELECT name, salary INTO :emp_name, :salary INDICATOR :salary_ind
         FROM employees WHERE id = :emp_id;
if (salary_ind == -1) { /* NULL — salary 값 사용 금지 */ }
```

### WHENEVER — 소스 순서로 적용되는 에러 정책

`WHENEVER`는 실행 흐름이 아니라 **선언 지점 이후의 소스 텍스트**에 적용된다.
함수마다 정책이 다르면 함수 진입부에서 다시 선언한다.

```c
EXEC SQL WHENEVER SQLERROR DO SqlErrorHandler();
EXEC SQL WHENEVER NOT FOUND DO break;        /* 단건 FETCH 루프 전용 — 배열 FETCH에는 쓰지 않는다 */
```

- `WHENEVER SQLERROR GOTO label`은 goto cleanup 패턴(`rules/c/patterns.md`)과 함께 쓸 때만 허용한다.
- 핸들러 안에서 SQL을 다시 실행하면 재귀가 생긴다. 핸들러 첫 줄에서
  `EXEC SQL WHENEVER SQLERROR CONTINUE;`로 해제한다.

### 커서와 트랜잭션 경계

```c
EXEC SQL DECLARE emp_cur CURSOR FOR SELECT id, name FROM employees WHERE dept = :dept_no;
EXEC SQL OPEN emp_cur;
EXEC SQL WHENEVER NOT FOUND DO break;
for (;;) {
    EXEC SQL FETCH emp_cur INTO :emp_id, :emp_name;
    ProcessEmployee(emp_id, emp_name);
}
EXEC SQL WHENEVER NOT FOUND CONTINUE;        /* 정책 원복 */
EXEC SQL CLOSE emp_cur;
```

- 임베디드 SQL은 기본이 **autocommit off**다(ecpg는 `-t` 옵션일 때만 on). 변경은 `COMMIT`·`ROLLBACK`으로 닫는다.
- 에러 핸들러의 기본 동작은 `ROLLBACK` 후 자원 정리다. 닫히지 않은 트랜잭션은 락을 쥔 채 남는다.
- 접속 종료는 Pro\*C `COMMIT WORK RELEASE`, ecpg `COMMIT` + `DISCONNECT`로 한다.

## Pro*C vs ecpg 차이표

| 항목 | Pro\*C (Oracle) | ecpg (PostgreSQL) |
|---|---|---|
| 프리컴파일 | `proc iname=f.pc oname=f.c` | `ecpg f.pgc -o f.c` |
| 연결 | `CONNECT :user IDENTIFIED BY :pass USING :db` | `CONNECT TO dbname@host AS conn USER :user` |
| 에러 판별 | `sqlca.sqlcode`(음수=에러) | `sqlca.sqlstate` 5자리 권장 |
| NOT FOUND | `+1403` | `ECPG_NOT_FOUND`(100) / SQLSTATE `02000` |
| 에러 메시지 | `sqlca.sqlerrm.sqlerrmc` | 같은 구조 |
| VARCHAR | `VARCHAR v[64];` → `.len`/`.arr` | 같은 문법 |
| 동적 SQL 자리표시자 | `:b1` 형태 | `?` |
| SQLCA | `#include <sqlca.h>` | `EXEC SQL INCLUDE sqlca;` |
| include·링크 | `$(ORACLE_HOME)/precomp/public`, `-lclntsh` | `pg_config --includedir`, `-lecpg -lpq` |
| 배열 DML | `FOR :n INSERT/UPDATE/DELETE` | 없음 — 배열은 조회 전용 |
| 처리 건수 `sqlerrd[2]` | 커서 FETCH는 **누적** 건수 | **마지막 문장** 건수 |
| 스레드 | `THREADS=YES` + `CONTEXT` | 스레드 안전 빌드 + 연결명 `AT` |

## 기본 예시 (Pro*C · ecpg)

```c
/* emp_report.pc — Pro*C (#include <sqlca.h>, explicit_bzero 는 glibc 2.25 이상 <string.h>) */
EXEC SQL BEGIN DECLARE SECTION;
    char    db_user[32];
    char    db_pass[32];
    int     emp_id;
    VARCHAR emp_name[64];
    short   name_ind;
EXEC SQL END DECLARE SECTION;

static void SqlErrorHandler(void)
{
    EXEC SQL WHENEVER SQLERROR CONTINUE;                 /* 재귀 방지 */
    fprintf(stderr, "[EMP] SQL 에러 %d: %.*s\n", sqlca.sqlcode,
            sqlca.sqlerrm.sqlerrml, sqlca.sqlerrm.sqlerrmc);
    EXEC SQL ROLLBACK WORK RELEASE;
    exit(1);
}

int main(void)
{
    /* 비밀값은 환경변수·권한 600 설정 파일에서 읽는다 */
    snprintf(db_user, sizeof(db_user), "%s", getenv("DB_USER"));
    snprintf(db_pass, sizeof(db_pass), "%s", getenv("DB_PASS"));
    EXEC SQL WHENEVER SQLERROR DO SqlErrorHandler();
    EXEC SQL CONNECT :db_user IDENTIFIED BY :db_pass;
    explicit_bzero(db_pass, sizeof(db_pass));            /* 접속 직후 소거 */

    emp_id = 42;
    EXEC SQL SELECT name INTO :emp_name INDICATOR :name_ind FROM employees WHERE id = :emp_id;
    if (sqlca.sqlcode == 1403)  printf("사원 %d 없음\n", emp_id);
    else if (name_ind != -1)    printf("%.*s\n", emp_name.len, emp_name.arr);
    EXEC SQL COMMIT WORK RELEASE;
    return 0;
}
```

```c
/* emp_report.pgc — ecpg: SQLSTATE 클래스로 분류한다. 자격증명은 PGUSER·PGPASSFILE 등 환경으로 넘긴다 */
static int CheckSql(const char *ctx)
{
    if (strncmp(sqlca.sqlstate, "00", 2) == 0) return 0;   /* 정상 */
    if (strncmp(sqlca.sqlstate, "02", 2) == 0) return 1;   /* NOT FOUND */
    fprintf(stderr, "[EMP] %s 실패 SQLSTATE=%.5s: %s\n", ctx, sqlca.sqlstate, sqlca.sqlerrm.sqlerrmc);
    EXEC SQL ROLLBACK;
    EXEC SQL DISCONNECT ALL;
    exit(1);
}
```

동적 SQL은 **문자열 연결 없이 바인딩만** 쓴다. 자리표시자는 Pro\*C가 `:b1`, ecpg가 `?`다.

```c
/* Pro*C */
snprintf(stmt_buf, sizeof(stmt_buf), "DELETE FROM employees WHERE salary < :b1");
EXEC SQL PREPARE del_stmt FROM :stmt_buf;
EXEC SQL EXECUTE del_stmt USING :min_salary;

/* ecpg */
EXEC SQL PREPARE upd_stmt FROM :stmt_text;   /* "UPDATE employees SET salary = ? WHERE id = ?" */
EXEC SQL EXECUTE upd_stmt USING :new_salary, :target_id;
EXEC SQL DEALLOCATE PREPARE upd_stmt;
```

## 호스트 배열 — 대량 처리

**단건 루프는 행마다 네트워크 왕복을 한 번씩 쓴다.** 호스트 배열은 한 번의 왕복으로 N행을 옮긴다.

### 배열 크기 산정

- 메모리는 `배열 크기 × 행 크기(호스트 변수 + 인디케이터)`다. 스레드 수만큼 곱해 상한을 확인한다.
- 시작값은 100~1,000행이다. 크기는 상수(`FETCH_BATCH`)로 두고 처리량과 RSS를 측정해 조정한다.
  왕복 시간이 처리 시간보다 충분히 작아지면 더 키워도 이득이 없다.

### 배열 FETCH — 마지막 부분 배치를 놓치지 않는다

Pro\*C는 `sqlca.sqlerrd[2]`에 **커서를 연 뒤 누적 건수**를 담는다. 이번 배치 건수는 직전 값과의 차이다.
마지막 FETCH는 1403을 반환하면서도 일부 행을 채운다. 그래서 **`WHENEVER NOT FOUND DO break`를 쓰면 마지막 부분 배치를 잃는다.**

```c
/* Pro*C — FETCH_BATCH 는 #define 상수 */
EXEC SQL BEGIN DECLARE SECTION;
    int   ord_ids[FETCH_BATCH];
    char  ord_memos[FETCH_BATCH][81];
    short memo_inds[FETCH_BATCH];
EXEC SQL END DECLARE SECTION;
long  prev_cnt = 0;
long  batch_cnt;

EXEC SQL WHENEVER NOT FOUND CONTINUE;
EXEC SQL OPEN ord_cur;
for (;;) {
    EXEC SQL FETCH ord_cur INTO :ord_ids, :ord_memos INDICATOR :memo_inds;
    if (sqlca.sqlcode < 0) { HandleSqlError(); break; }
    batch_cnt = sqlca.sqlerrd[2] - prev_cnt;            /* 누적 → 이번 배치 */
    prev_cnt  = sqlca.sqlerrd[2];
    if (batch_cnt > 0) ProcessOrders(ord_ids, ord_memos, memo_inds, batch_cnt);
    if (sqlca.sqlcode == 1403) break;                   /* 부분 배치 처리 후 종료 */
}
EXEC SQL CLOSE ord_cur;
```

ecpg는 FETCH에 행 수를 적고, `sqlerrd[2]`는 **이번 FETCH의 건수**다.

```c
/* ecpg */
for (;;) {
    EXEC SQL FETCH FORWARD 500 FROM ord_cur INTO :ord_ids, :ord_memos INDICATOR :memo_inds;
    if (strncmp(sqlca.sqlstate, "02", 2) == 0) break;   /* 남은 행 없음 */
    if (CheckSql("fetch") != 0) break;
    batch_cnt = sqlca.sqlerrd[2];
    ProcessOrders(ord_ids, ord_memos, memo_inds, batch_cnt);
    if (batch_cnt < 500) break;                         /* 마지막 부분 배치 */
}
```

### 배열 INSERT·UPDATE — Pro*C `FOR :n`

`FOR :n`은 배열 앞쪽 n행만 실행한다. 마지막 부분 배치에서 쓰레기 행이 들어가지 않게 반드시 지정한다.

```c
EXEC SQL BEGIN DECLARE SECTION;
    int   row_cnt;                                      /* FOR 절 변수도 호스트 변수 */
EXEC SQL END DECLARE SECTION;

row_cnt = filled;                                       /* 1 ≤ row_cnt ≤ FETCH_BATCH */
EXEC SQL FOR :row_cnt
    INSERT INTO orders_hist (id, memo) VALUES (:ord_ids, :ord_memos INDICATOR :memo_inds);
```

**부분 실패 처리:** 배열 DML 중 i번째 행이 실패하면 `sqlca.sqlerrd[2]`는 **실패 전까지 처리된 행 수**다.
이 행들은 아직 커밋되지 않았다. 다음 두 정책 중 하나를 배치 단위로 정해 둔다.

| 정책 | 동작 |
|---|---|
| 전부 아니면 전무 | `ROLLBACK` 후 배치 전체를 오류 처리·재시도 |
| 불량 행 격리 | `sqlerrd[2]`번 행을 오류 테이블·로그로 보내고, `sqlerrd[2] + 1`번부터 남은 행을 다시 `FOR`로 실행 |

ecpg에는 `FOR :n` 배열 DML이 없다. 배열 호스트 변수는 조회(SELECT·FETCH)에만 쓴다.
ecpg의 대량 쓰기는 준비된 문장을 루프로 실행하고 커밋 주기로 묶는다. 실패한 문장은 트랜잭션 전체를
중단 상태로 만든다. 행 단위로 건너뛰려면 `SAVEPOINT`·`ROLLBACK TO SAVEPOINT`로 감싼다.
처리량이 더 필요하면 libpq `COPY`(아래 예외 경로)를 쓴다.

## 멀티스레드 서버

**원칙: 스레드 하나에 연결 하나다.** 연결(컨텍스트)을 여러 스레드가 동시에 쓰면 프로토콜이 깨진다.
풀로 공유하더라도 한 시점에는 한 스레드만 빌려 쓴다.

### Pro*C — `THREADS=YES` + 런타임 컨텍스트

- 프리컴파일 옵션 `threads=yes`를 켠다. 끄면 `CONTEXT` 구문이 무시되거나 오류가 난다.
- 스레드를 만들기 전에 프로세스에서 `EXEC SQL ENABLE THREADS;`를 한 번 실행한다.
- 스레드마다 `sql_context`를 `CONTEXT ALLOCATE`로 만들고, 끝날 때 `CONTEXT FREE`로 해제한다.
- `CONTEXT USE`는 `WHENEVER`처럼 **소스 순서로 적용되는 선언**이다. 컨텍스트를 인자로 받고
  SQL을 실행하는 함수마다 앞에서 `EXEC SQL CONTEXT USE :ctx;`를 다시 쓴다.
- `THREADS=YES`에서는 SQLCA를 스레드별로 둔다. SQL을 실행하는 함수마다 `struct sqlca sqlca;`를 지역으로 선언한다.
  생성 코드는 그 위치에서 보이는 `sqlca`를 쓰므로, 전역 SQLCA를 스레드가 공유하면 오류 정보가 섞인다.

```c
/*=== 워커 스레드 — 스레드별 컨텍스트 하나 ===*/
static void *DbWorkerMain(void *arg)
{
    struct sqlca sqlca;                                 /* 스레드별 SQLCA */
    EXEC SQL BEGIN DECLARE SECTION;
        sql_context ctx;
    EXEC SQL END DECLARE SECTION;

    EXEC SQL CONTEXT ALLOCATE :ctx;
    EXEC SQL CONTEXT USE :ctx;
    if (ConnectWithRetry(ctx) == 0)                     /* 함수 안에서도 CONTEXT USE :ctx */
    {
        RunJobs(ctx, arg);
        EXEC SQL COMMIT WORK RELEASE;
    }
    EXEC SQL CONTEXT FREE :ctx;
    return NULL;
}
```

### ecpg — 연결명 + `AT`

- ecpg 라이브러리는 스레드 안전 빌드여야 한다. PostgreSQL 16 이하는 `--enable-thread-safety`(기본 on)로
  빌드됐는지 확인한다. 17부터는 항상 스레드 안전이다.
- 스레드 안전 빌드에서 SQLCA는 스레드별로 관리된다. 현재 연결(`SET CONNECTION`)도 스레드별이다.
- 스레드마다 고유 연결명으로 접속하고, 모든 문장에 `AT`를 붙여 대상 연결을 명시한다.

```c
EXEC SQL BEGIN DECLARE SECTION;
    char conn_name[32];
EXEC SQL END DECLARE SECTION;

snprintf(conn_name, sizeof(conn_name), "worker_%d", worker_idx);
EXEC SQL CONNECT TO :db_target AS :conn_name;
EXEC SQL AT :conn_name SELECT count(*) INTO :row_total FROM orders;
EXEC SQL AT :conn_name COMMIT;
EXEC SQL DISCONNECT :conn_name;
```

- 커서·준비된 문장도 연결에 묶인다. `DECLARE`·`PREPARE`에도 같은 `AT`를 붙인다.

## 재접속 — 연결 끊김 분류와 재시도

**연결 끊김은 일반 SQL 오류와 다르게 처리한다.** 같은 연결에서 재시도해도 계속 실패하기 때문이다.

| DB | 연결 끊김으로 분류 |
|---|---|
| Oracle | ORA-03113(통신 채널 EOF), ORA-03114(연결 안 됨), ORA-03135(연결 끊김) |
| PostgreSQL | SQLSTATE 클래스 `08`(`08000`·`08003`·`08006` 등), ecpg `ECPG_NO_CONN`, 관리자 종료 `57P01` |

```c
static int IsConnectionLost(void)
{
#ifdef USE_ORACLE
    int code = -sqlca.sqlcode;
    return code == 3113 || code == 3114 || code == 3135;
#else
    return strncmp(sqlca.sqlstate, "08", 2) == 0 || strncmp(sqlca.sqlstate, "57P01", 5) == 0;
#endif
}
```

재시도 정책은 다음을 지킨다.

- **횟수 상한을 둔다.** 예: 5회. 상한을 넘으면 상위로 실패를 보고하고 서비스 상태를 강등한다.
- **지수 백오프 + 지터를 쓴다.** 예: 200ms에서 시작해 두 배씩, 최대 10s. 모든 스레드가 동시에 붙지 않게 한다.
- 끊긴 연결의 정리 호출(`ROLLBACK WORK RELEASE`, `DISCONNECT`)은 실패해도 무시하고 새로 접속한다.
- **재접속 뒤에는 커서·준비된 문장·세션 설정이 모두 사라진다.** 다시 `PREPARE`·`OPEN`하고 세션 설정을 복원한다.
- **재시도 단위는 트랜잭션 전체다.** 끊긴 시점의 미커밋 작업은 이미 롤백됐다.
- **`COMMIT` 중 끊기면 결과를 알 수 없다.** 다시 실행하기 전에 업무 키로 반영 여부를 조회한다.
  멱등하지 않은 작업(채번·누적 갱신)은 자동 재실행하지 않는다.

## 커밋 주기 — 대량 작업

- **N행마다 커밋한다.** 시작값은 1,000~10,000행이며 측정으로 정한다.
- 너무 잦으면 커밋마다 로그 플러시(Oracle `log file sync`, PG WAL fsync)가 처리량을 깎는다.
- 너무 드물면 undo·락·WAL이 쌓이고, 실패 시 재처리량이 커진다. PG는 긴 트랜잭션이 VACUUM을 막는다.
- **재시작 지점을 남긴다.** 커밋과 같은 트랜잭션에 "마지막 처리 키"를 기록하면 중단 후 그 키부터 이어 간다.
- 열린 커서를 FETCH하면서 같은 연결로 커밋하지 않는다. Oracle은 ORA-01555 위험이 커지고,
  PG는 `WITH HOLD`가 아닌 커서가 커밋에서 닫힌다. 키 범위로 배치를 나누는 방식이 안전하다.

## PostgreSQL `COPY` — libpq 예외 경로

ecpg는 `COPY ... FROM STDIN`을 지원하지 않는다. 최대 적재 처리량이 필요하면 **이 경로만 libpq로 쓴다.**
`ECPGget_PGconn(conn_name)`으로 ecpg 연결의 `PGconn`을 얻어 같은 세션에서 실행한다.

```c
PGconn   *conn = ECPGget_PGconn("loader");
PGresult *res  = PQexec(conn, "COPY orders_stage (id, memo) FROM STDIN");
if (PQresultStatus(res) != PGRES_COPY_IN) { /* 오류 처리 */ }
PQclear(res);
/* 행마다 PQputCopyData(conn, line, line_len) — 반환값 -1 이면 중단 */
PQputCopyEnd(conn, NULL);
res = PQgetResult(conn);                     /* PGRES_COMMAND_OK 확인 후 PQclear */
```

COPY 텍스트 형식은 탭·개행·역슬래시를 이스케이프해야 한다. 스테이징 설계는 `postgres-patterns` "대량 적재"를 본다.

## 빌드 통합 (Makefile)

```makefile
CFLAGS = -std=c11 -Wall -Wextra -g

%.c: %.pc            # Pro*C — lines=yes 로 #line 을 넣어 오류·sanitizer 위치가 .pc 를 가리키게 한다
	proc iname=$< oname=$@ code=ANSI_C sqlcheck=SEMANTICS threads=yes lines=yes \
	     userid=$${DB_USER}/$${DB_PASS}
%.c: %.pgc           # ecpg — #line 지시자를 기본으로 넣는다
	ecpg $< -o $@

ORA_FLAGS = -I$(ORACLE_HOME)/precomp/public -L$(ORACLE_HOME)/lib -lclntsh
PG_FLAGS  = -I$(shell pg_config --includedir) -L$(shell pg_config --libdir) -lecpg -lpq
```

- `sqlcheck=SEMANTICS`는 프리컴파일 때 스키마와 대조한다(접속 필요). CI에 DB가 없으면 `sqlcheck=SYNTAX`로 낮춘다.
- 멀티스레드 프로그램은 `-pthread`로 빌드한다. 생성 `.c`는 `clean`에서 지우고 커밋하지 않는다.

## 보안 체크 (커밋 전)

- [ ] 동적 SQL에 문자열 연결이 없다 — `PREPARE` + `USING` 바인딩만 쓴다.
- [ ] 접속 정보를 하드코딩하지 않는다. `CONNECT`에는 호스트 변수만 넘기고 값은 환경변수·권한 600 파일에서 읽는다.
- [ ] 비밀번호 호스트 변수는 `CONNECT` 직후 `explicit_bzero`로 지운다(`VARCHAR`면 `.arr`와 `.len` 모두).
- [ ] `char` 호스트 변수 크기는 컬럼 크기 + 1(NUL)이다. 절단은 인디케이터 `>0`으로 감지한다.
- [ ] 에러 경로마다 ROLLBACK, 커서 CLOSE, DISCONNECT가 있다.
- [ ] 에러 메시지에 스키마·비밀값을 노출하지 않는다.
- [ ] SQL 트레이스는 바인드 값을 남길 수 있다. 운영에서는 끄고, 켜면 로그를 개인정보로 취급한다(`sensitive-data-handling`).

## 테스트 전략

- **SQL 로직과 순수 로직을 분리한다.** 파싱·계산은 일반 `.c`로 빼서 `c-testing`(cmocka)으로 검증한다.
- 임베디드 부분은 **테스트 DB 통합 테스트**로 검증한다. 테스트별 고유 스키마를 만들고 끝나면 DROP한다.
- 호스트 배열 테스트에는 0행, 정확히 배열 크기, 배열 크기 + 1행, NULL 섞인 행을 넣는다.
- ecpg는 로컬 PostgreSQL로 CI가 가능하다. Pro\*C는 Oracle이 없으면 프리컴파일(`sqlcheck=SYNTAX`) 통과까지만 게이트로 둔다.
- **생성된 C를 valgrind·ASan으로 돌린다.** 호스트 배열 경계 초과, VARCHAR 길이 오류, 인디케이터 누락은
  여기서 드러난다. 멀티스레드 경로는 TSan을 통과하기 전까지 완료로 보지 않는다(`memory-check`).
- DB 클라이언트 라이브러리(`libclntsh`·`libpq`) 내부 오탐은 suppression 파일로만 제외한다.

## 이식 노트 (Oracle ↔ PostgreSQL)

- `sqlca.sqlcode` 체계가 다르다. 판별은 **SQLSTATE 기준**으로 쓰면 이식이 쉽다(Pro\*C는 `MODE=ANSI`에서 제공).
- `SYSDATE` ↔ `CURRENT_TIMESTAMP`, `NVL` ↔ `COALESCE`, `ROWNUM` ↔ `LIMIT` 같은 방언 차이는 뷰·함수로 격리한다.
- `CONNECT`·스레드 컨텍스트·배열 DML은 양쪽이 비호환이다. 접속·배치 쓰기 함수 하나로 감싸 조건부 컴파일한다.
- Oracle은 `''`를 NULL로 취급하고 PostgreSQL은 빈 문자열로 취급한다(`oracle-patterns`).
