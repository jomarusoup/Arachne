################################################################################
# FILE NAME   : 0002_create_orders.py
# DESCRIPTION : orders 테이블 생성 — idempotency unique, Numeric 금액, check 제약
# DATA        : 2026-06-11
# Modification: 2026-06-11
################################################################################
import sqlalchemy as sa
from alembic import op

revision = "0002_create_orders"
down_revision = "0001_create_users"
branch_labels = None
depends_on = None


#===============================================================================
# FUNCTION    : upgrade
# DESCRIPTION : orders 테이블·제약·인덱스 생성
#===============================================================================
def upgrade() -> None:
    op.create_table(
        "orders",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column(
            "user_id",
            sa.Integer(),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("idempotency_key", sa.String(64), nullable=False),
        sa.Column("amount", sa.Numeric(18, 2), nullable=False),
        sa.Column("currency", sa.String(3), nullable=False),
        sa.Column("status", sa.String(20), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.UniqueConstraint("idempotency_key", name="uq_orders_idempotency_key"),
        sa.CheckConstraint("amount >= 0", name="ck_orders_amount_non_negative"),
    )
    op.create_index("ix_orders_user_id", "orders", ["user_id"])


#===============================================================================
# FUNCTION    : downgrade
# DESCRIPTION : 미구현 — 배포 후 되돌림은 forward-fix revision으로 처리
#===============================================================================
def downgrade() -> None:
    raise NotImplementedError(
        "forward-fix 원칙 — downgrade 대신 새 revision을 추가한다 (docs/DATA-HANDLING.md)"
    )
