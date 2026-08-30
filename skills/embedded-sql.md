---
name: embedded-sql
description: 임베디드 SQL 프로그래밍 — Oracle Pro*C(*.pc)와 PostgreSQL ecpg(*.pgc). 호스트/인디케이터 변수·SQLCA 에러 처리·커서·동적 SQL·프리컴파일 빌드 통합·트랜잭션 패턴.
triggers:
  paths: ["**/*.pc", "**/*.pgc"]
  keywords: ["Pro*C", "ecpg", "임베디드 SQL", "SQLCA", "호스트 변수", "프리컴파일"]
---

# 임베디드 SQL (Pro*C · ecpg)

C 소스에 `EXEC SQL` 구문을 내장해 프리컴파일러가 DB 라이브러리 호출로 변환하는
임베디드 SQL 워크플로. Oracle **Pro\*C**(`*.pc`)와 PostgreSQL **ecpg**(`*.pgc`)를
공통 개념 + 차이표로 함께 다룬다.

## 언제 사용하나

- `*.pc`(Pro\*C) / `*.pgc`(ecpg) 파일 작성·수정·리뷰
- 호스트 변수·인디케이터 변수·커서·동적 SQL 설계
- SQLCA/SQLSTATE 기반 에러 처리·트랜잭션 경계 구현
- 프리컴파일 단계를 Makefile/CMake에 통합
- Oracle ↔ PostgreSQL 임베디드 코드 이식

### 언제 사용하지 않나

- 일반 C 코드 → `rules/c/*`, `linux-system-network-programming`
- 애플리케이션 레벨 DB 접근(ORM·드라이버 API 직접 호출) → `postgres-patterns`, `backend-patterns`
- 스키마·migration 설계 → `database-migrations`, `database-reviewer` 에이전트

## 공통 개념

### 파이프라인

```
소스(.pc/.pgc) ── 프리컴파일러(proc/ecpg) ──▶ 순수 C(.c) ── cc ──▶ 실행 파일
```

- **`.pc`/`.pgc`가 소스다** — 생성된 `.c`는 빌드 산출물이므로 VCS에 커밋하지 않는다
  (`.gitignore`에 생성 `.c` 등록, 헤더 주석·리뷰·수정 모두 `.pc`/`.pgc` 대상).
- 프리컴파일러는 `EXEC SQL` 블록만 해석하고 나머지 C 코드는 그대로 통과시킨다.

### 호스트 변수 · 인디케이터 변수

C 변수를 SQL에 바인딩하려면 DECLARE SECTION에 선언하고 `:이름`으로 참조한다.
**NULL 판별은 인디케이터 변수가 유일한 수단** — 인디케이터 없이 NULL을 읽으면
Pro\*C는 ORA-01405 에러, ecpg는 경고 후 쓰레기 값이 된다.

```c
EXEC SQL BEGIN DECLARE SECTION;
    int     emp_id;
    char    emp_name[64];
    double  salary;
    short   salary_ind;         /* 인디케이터: -1=NULL, 0=정상, >0=절단 */
EXEC SQL END DECLARE SECTION;

EXEC SQL SELECT name, salary
         INTO :emp_name, :salary INDICATOR :salary_ind
         FROM employees WHERE id = :emp_id;

if (salary_ind == -1) {
    /* salary 는 NULL — 값 사용 금지 */
}
```

### WHENEVER — 전역 에러 정책

`WHENEVER`는 **선언 지점 이후의 소스 텍스트 순서**로 적용된다(실행 흐름 아님).
함수마다 정책이 달라지면 함수 진입부에서 재선언한다.

```c
EXEC SQL WHENEVER SQLERROR DO SqlErrorHandler();  /* 에러 → 핸들러 */
EXEC SQL WHENEVER NOT FOUND DO break;             /* 커서 루프 종료 */
```

> `WHENEVER SQLERROR GOTO label`은 goto cleanup 패턴(`rules/c/patterns.md`)과
> 결합할 때만 사용하고, 핸들러 안에서 다시 SQL을 실행할 경우 무한 재귀를 막기 위해
> 핸들러 진입 직후 `EXEC SQL WHENEVER SQLERROR CONTINUE;`로 해제한다.

### 커서 패턴 (공통 형태)

```c
EXEC SQL DECLARE emp_cur CURSOR FOR
    SELECT id, name FROM employees WHERE dept = :dept_no;

EXEC SQL OPEN emp_cur;
EXEC SQL WHENEVER NOT FOUND DO break;
for (;;) {
    EXEC SQL FETCH emp_cur INTO :emp_id, :emp_name;
    ProcessEmployee(emp_id, emp_name);
}
EXEC SQL WHENEVER NOT FOUND CONTINUE;   /* 정책 원복 */
EXEC SQL CLOSE emp_cur;
```

### 트랜잭션 경계

- 임베디드 SQL은 기본 **autocommit off** (ecpg는 `-t` 옵션으로만 on) —
  모든 변경은 명시적 `EXEC SQL COMMIT;` / `EXEC SQL ROLLBACK;`으로 닫는다.
- 에러 핸들러의 기본 동작은 `ROLLBACK` 후 자원 정리 — 커밋되지 않은 좀비
  트랜잭션은 락을 쥔 채 남는다.
- 접속 종료 전 `COMMIT WORK RELEASE`(Pro\*C) / `COMMIT` + `DISCONNECT`(ecpg).

## Pro*C vs ecpg 차이표

| 항목 | Pro\*C (Oracle) | ecpg (PostgreSQL) |
|---|---|---|
| 소스 확장자 | `*.pc` | `*.pgc` |
| 프리컴파일러 | `proc iname=f.pc oname=f.c` | `ecpg f.pgc -o f.c` |
| 연결 | `EXEC SQL CONNECT :user IDENTIFIED BY :pass USING :db;` | `EXEC SQL CONNECT TO dbname@host AS conn USER :user;` |
| 에러 판별 | `sqlca.sqlcode` (음수=에러, 1403=NOT FOUND) | `sqlca.sqlcode` + **SQLSTATE 5자리**(`sqlca.sqlstate`) 권장 |
| 에러 메시지 | `sqlca.sqlerrm.sqlerrmc` | `sqlca.sqlerrm.sqlerrmc` (동일 구조) |
| NOT FOUND 코드 | `+1403` | `ECPG_NOT_FOUND (-243)` / SQLSTATE `02000` |
| VARCHAR | `VARCHAR name[64];` → `.len`/`.arr` 구조체 생성 | 동일 문법 지원 (`ecpg`가 struct 변환) |
| 동적 SQL | PREPARE/EXECUTE + DESCRIBE (ANSI 방법 1~4) | PREPARE/EXECUTE + SQLDA (descriptor 권장) |
| 헤더 | `#include <sqlca.h>` (proc가 주입 가능) | `EXEC SQL INCLUDE sqlca;` |
| 컴파일 include | `$ORACLE_HOME/precomp/public` | `$(pg_config --includedir)` |
| 링크 | `-L$ORACLE_HOME/lib -lclntsh` | `-L$(pg_config --libdir) -lecpg -lpq` |
| 다중 접속 | `AT db_name` 절 | `AT conn_name` 절 (동일 개념) |

## Pro*C 예시

```c
/* emp_report.pc */
#include <stdio.h>
#include <sqlca.h>

EXEC SQL BEGIN DECLARE SECTION;
    char    db_user[32];
    char    db_pass[32];
    int     emp_id;
    VARCHAR emp_name[64];       /* proc가 { len, arr } 구조체로 변환 */
    short   name_ind;
EXEC SQL END DECLARE SECTION;

/*=== SQL 에러 공통 핸들러 — ROLLBACK 후 종료 ===*/
static void SqlErrorHandler(void)
{
    EXEC SQL WHENEVER SQLERROR CONTINUE;            /* 재귀 방지 */
    fprintf(stderr, "[EMP] SQL 에러 %d: %.*s\n",
            sqlca.sqlcode,
            sqlca.sqlerrm.sqlerrml, sqlca.sqlerrm.sqlerrmc);
    EXEC SQL ROLLBACK WORK RELEASE;
    exit(1);
}

int main(void)
{
    /* 비밀값은 환경변수로 — 소스 하드코딩 금지 (rules/common/security.md) */
    snprintf((char *)db_user, sizeof(db_user), "%s", getenv("DB_USER"));
    snprintf((char *)db_pass, sizeof(db_pass), "%s", getenv("DB_PASS"));

    EXEC SQL WHENEVER SQLERROR DO SqlErrorHandler();
    EXEC SQL CONNECT :db_user IDENTIFIED BY :db_pass;

    emp_id = 42;
    EXEC SQL SELECT name INTO :emp_name INDICATOR :name_ind
             FROM employees WHERE id = :emp_id;

    if (sqlca.sqlcode == 1403) {                    /* NOT FOUND */
        printf("사원 %d 없음\n", emp_id);
    } else if (name_ind != -1) {
        printf("%.*s\n", emp_name.len, emp_name.arr);
    }

    EXEC SQL COMMIT WORK RELEASE;
    return 0;
}
```

### Pro*C 동적 SQL (바인딩 필수)

```c
EXEC SQL BEGIN DECLARE SECTION;
    char stmt_buf[256];
    int  min_salary;
EXEC SQL END DECLARE SECTION;

/* GOOD: 플레이스홀더 + 호스트 변수 바인딩 */
snprintf(stmt_buf, sizeof(stmt_buf),
         "DELETE FROM employees WHERE salary < :b1");
EXEC SQL PREPARE del_stmt FROM :stmt_buf;
EXEC SQL EXECUTE del_stmt USING :min_salary;

/* BAD: 사용자 입력 문자열 연결 → SQL 인젝션 */
/* snprintf(stmt_buf, ..., "... WHERE name = '%s'", user_input); */
```

## ecpg 예시

```c
/* emp_report.pgc */
#include <stdio.h>
#include <string.h>

EXEC SQL INCLUDE sqlca;

EXEC SQL BEGIN DECLARE SECTION;
    int     emp_id;
    char    emp_name[64];
    short   name_ind;
EXEC SQL END DECLARE SECTION;

/*=== SQLSTATE 5자리로 에러 분류 — sqlcode보다 이식성 높음 ===*/
static int CheckSql(const char *ctx)
{
    if (strncmp(sqlca.sqlstate, "00", 2) == 0) return 0;   /* 정상 */
    if (strncmp(sqlca.sqlstate, "02", 2) == 0) return 1;   /* NOT FOUND */
    fprintf(stderr, "[EMP] %s 실패 SQLSTATE=%.5s: %s\n",
            ctx, sqlca.sqlstate, sqlca.sqlerrm.sqlerrmc);
    EXEC SQL ROLLBACK;
    EXEC SQL DISCONNECT ALL;
    exit(1);
}

int main(void)
{
    /* 접속 문자열도 환경변수 기반 (예: PGHOST/PGUSER/PGPASSWORD 활용) */
    EXEC SQL CONNECT TO mydb AS conn;
    CheckSql("connect");

    emp_id = 42;
    EXEC SQL SELECT name INTO :emp_name INDICATOR :name_ind
             FROM employees WHERE id = :emp_id;

    if (CheckSql("select") == 1) {
        printf("사원 %d 없음\n", emp_id);
    } else if (name_ind != -1) {
        printf("%s\n", emp_name);
    }

    EXEC SQL COMMIT;
    EXEC SQL DISCONNECT conn;
    return 0;
}
```

### ecpg 동적 SQL

```c
EXEC SQL BEGIN DECLARE SECTION;
    const char *stmt_text = "UPDATE employees SET salary = $1 WHERE id = $2";
    double      new_salary;
    int         target_id;
EXEC SQL END DECLARE SECTION;

EXEC SQL PREPARE upd_stmt FROM :stmt_text;      /* $1, $2 플레이스홀더 */
EXEC SQL EXECUTE upd_stmt USING :new_salary, :target_id;
EXEC SQL DEALLOCATE PREPARE upd_stmt;
```

## 빌드 통합 (Makefile)

```makefile
CFLAGS = -std=c11 -Wall -Wextra -g

#--- Pro*C: .pc → .c (ORACLE_HOME 필수) ------------------------------
%.c: %.pc
	proc iname=$< oname=$@ code=ANSI_C sqlcheck=SEMANTICS \
	     userid=$${DB_USER}/$${DB_PASS}
ORA_INC  = -I$(ORACLE_HOME)/precomp/public
ORA_LIBS = -L$(ORACLE_HOME)/lib -lclntsh

emp_report_ora: emp_report.c
	$(CC) $(CFLAGS) $(ORA_INC) -o $@ $< $(ORA_LIBS)

#--- ecpg: .pgc → .c -------------------------------------------------
%.c: %.pgc
	ecpg $< -o $@
PG_INC  = -I$(shell pg_config --includedir)
PG_LIBS = -L$(shell pg_config --libdir) -lecpg -lpq

emp_report_pg: emp_report.c
	$(CC) $(CFLAGS) $(PG_INC) -o $@ $< $(PG_LIBS)

clean:
	rm -f emp_report.c            # 생성 .c 는 산출물 — VCS 미추적
```

> `sqlcheck=SEMANTICS`는 프리컴파일 시점에 스키마 대조 검증을 수행한다(접속 필요).
> CI에서 DB 접속이 없으면 `sqlcheck=SYNTAX`로 낮춘다.

## 보안 체크 (커밋 전)

- [ ] 동적 SQL에 **문자열 연결 금지** — PREPARE + `USING` 호스트 변수 바인딩만
- [ ] 접속 정보 하드코딩 없음 — 환경변수·시크릿 매니저 (`rules/common/security.md`)
- [ ] `char` 호스트 변수 크기 = 컬럼 크기 + 1(종단 NUL) — 절단은 인디케이터 `>0`으로 감지
- [ ] 에러 경로마다 ROLLBACK + 커서 CLOSE + DISCONNECT (자원 누수 방지)
- [ ] 에러 메시지에 스키마·비밀값 노출 금지

## 테스트 전략

- **SQL 로직과 순수 로직 분리** — 파싱·계산은 일반 `.c`로 추출해 `c-testing`
  (cmocka) 대상으로, `.pc`/`.pgc`에는 DB 왕복만 남긴다.
- 임베디드 부분은 **테스트 DB 대상 통합 테스트**로 검증 — 픽스처 스키마를
  테스트 시작 시 생성, 종료 시 DROP (테스트별 고유 스키마 이름).
- ecpg는 로컬 PostgreSQL로 CI 가능. Pro\*C는 Oracle 인스턴스 필요 —
  불가하면 프리컴파일(`sqlcheck=SYNTAX`) 통과까지만 CI 게이트로.
- valgrind 게이팅 시 DB 클라이언트 라이브러리 내부 오탐은 suppression 파일로 제외.

## 이식 노트 (Oracle ↔ PostgreSQL)

- `sqlca.sqlcode` 값 체계가 다르다 — 판별 로직은 **SQLSTATE 기준**으로 작성하면
  양쪽 이식이 쉽다 (Pro\*C는 `MODE=ANSI`에서 SQLSTATE 제공).
- Oracle `SYSDATE` ↔ PG `CURRENT_TIMESTAMP`, `NVL` ↔ `COALESCE`,
  `ROWNUM` ↔ `LIMIT` 등 SQL 방언 차이는 뷰·함수로 격리한다.
- `CONNECT` 구문은 양쪽이 비호환 — 접속 함수 하나로 감싸 조건부 컴파일한다.
