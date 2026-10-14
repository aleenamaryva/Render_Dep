"""Add roles and response rescue status.

Revision ID: 0002_roles_and_response_status
Revises: 0001_initial
"""
from alembic import op
import sqlalchemy as sa

revision = "0002_roles_and_response_status"
down_revision = "0001_initial"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("users", sa.Column("role", sa.String(length=20), nullable=False, server_default="citizen"))
    with op.batch_alter_table("disaster_responses", recreate="always") as batch_op:
        batch_op.add_column(
            sa.Column("rescue_status", sa.String(length=20), nullable=False, server_default="PENDING")
        )
        batch_op.add_column(sa.Column("status_updated_at", sa.DateTime(timezone=True), nullable=True))
        batch_op.add_column(sa.Column("status_updated_by", sa.String(length=36), nullable=True))
        batch_op.create_foreign_key(
            "fk_disaster_responses_status_updated_by_users",
            "users",
            ["status_updated_by"],
            ["id"],
        )


def downgrade() -> None:
    with op.batch_alter_table("disaster_responses", recreate="always") as batch_op:
        batch_op.drop_constraint("fk_disaster_responses_status_updated_by_users", type_="foreignkey")
        batch_op.drop_column("status_updated_by")
        batch_op.drop_column("status_updated_at")
        batch_op.drop_column("rescue_status")
    op.drop_column("users", "role")
