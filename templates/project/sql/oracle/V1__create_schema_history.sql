-- 스키마 적용 기록 테이블 (Oracle). apply-schema.sh 가 적용한 파일마다 한 행을 남긴다.
-- 규약: skills/sql-schema-versioning/SKILL.md
CREATE TABLE SCHEMA_HISTORY (
    installed_rank  NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    version         VARCHAR2(50),
    description     VARCHAR2(200)  NOT NULL,
    script          VARCHAR2(1000) NOT NULL,
    checksum        NUMBER(10),
    applied_by      VARCHAR2(100)  NOT NULL,
    applied_at      TIMESTAMP      DEFAULT SYSTIMESTAMP NOT NULL
);
CREATE INDEX SCHEMA_HISTORY_VERSION_IX ON SCHEMA_HISTORY (version);
