-- 스키마 적용 기록 테이블 (PostgreSQL). apply-schema.sh 가 적용한 파일마다 한 행을 남긴다.
-- 규약: skills/sql-schema-versioning/SKILL.md
CREATE TABLE schema_history (
    installed_rank  integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    version         varchar(50),
    description     varchar(200)  NOT NULL,
    script          varchar(1000) NOT NULL,
    checksum        bigint,
    applied_by      varchar(100)  NOT NULL,
    applied_at      timestamptz   NOT NULL DEFAULT now()
);
CREATE INDEX schema_history_version_ix ON schema_history (version);
