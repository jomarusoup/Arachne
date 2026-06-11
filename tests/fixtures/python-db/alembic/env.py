################################################################################
# FILE NAME   : env.py
# DESCRIPTION : Alembic migration 실행 환경 — DATABASE_URL 우선, sqlite 기본
# DATA        : 2026-06-11
# Modification: 2026-06-11
################################################################################
import os

from alembic import context
from sqlalchemy import create_engine

config = context.config


#===============================================================================
# FUNCTION    : database_url
# DESCRIPTION : 적용 대상 DB URL 결정 — DATABASE_URL 환경변수 우선
# RETURNED    : str DB 접속 URL
#===============================================================================
def database_url() -> str:
    return os.environ.get("DATABASE_URL", config.get_main_option("sqlalchemy.url"))


#===============================================================================
# FUNCTION    : run_migrations_offline
# DESCRIPTION : DB 연결 없이 SQL 스크립트만 생성하는 offline 모드
#===============================================================================
def run_migrations_offline() -> None:
    context.configure(url=database_url(), literal_binds=True)
    with context.begin_transaction():
        context.run_migrations()


#===============================================================================
# FUNCTION    : run_migrations_online
# DESCRIPTION : 실제 DB 연결로 migration 적용
#===============================================================================
def run_migrations_online() -> None:
    engine = create_engine(database_url())
    with engine.connect() as connection:
        context.configure(connection=connection)
        with context.begin_transaction():
            context.run_migrations()
    engine.dispose()


if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
