################################################################################
# FILE NAME   : 0001_create_users.py
# DESCRIPTION : users 테이블 생성 — email unique, tz-aware created_at
# DATA        : 2026-06-11
# Modification: 2026-06-11
################################################################################
import sqlalchemy as sa
from alembic import op

revision = "0001_create_users"
down_revision = None
branch_labels = None
depends_on = None


#===============================================================================
# FUNCTION    : upgrade
# DESCRIPTION : users 테이블과 unique 제약 생성
#===============================================================================
def upgrade() -> None:
    op.create_table(
        "users",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("email", sa.String(255), nullable=False),
        sa.Column("password_hash", sa.String(255), nullable=False),
        sa.Column("display_name", sa.String(100), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.UniqueConstraint("email", name="uq_users_email"),
    )


#===============================================================================
# FUNCTION    : downgrade
# DESCRIPTION : 미구현 — 배포 후 되돌림은 forward-fix revision으로 처리
#===============================================================================
def downgrade() -> None:
    raise NotImplementedError(
        "forward-fix 원칙 — downgrade 대신 새 revision을 추가한다 (docs/DATA-HANDLING.md)"
    )
