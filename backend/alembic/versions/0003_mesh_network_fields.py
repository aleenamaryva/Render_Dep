"""Add mesh network fields to disaster_responses.

Revision ID: 0003_mesh_network_fields
Revises: 0002_roles_and_response_status
"""
from alembic import op
import sqlalchemy as sa

revision = "0003_mesh_network_fields"
down_revision = "0002_roles_and_response_status"
branch_labels = None
depends_on = None


def upgrade() -> None:
    with op.batch_alter_table("disaster_responses", recreate="always") as batch_op:
        batch_op.add_column(
            sa.Column("packet_id", sa.String(length=64), nullable=True)
        )
        batch_op.add_column(
            sa.Column("is_mesh_relayed", sa.Boolean(), nullable=False, server_default="0")
        )
        batch_op.add_column(
            sa.Column("hop_count", sa.Integer(), nullable=False, server_default="0")
        )
        batch_op.add_column(
            sa.Column("relayed_by_user_id", sa.String(length=36), nullable=True)
        )
        batch_op.create_index("ix_disaster_responses_packet_id", ["packet_id"], unique=True)
        batch_op.create_foreign_key(
            "fk_disaster_responses_relayed_by_user_id_users",
            "users",
            ["relayed_by_user_id"],
            ["id"],
        )


def downgrade() -> None:
    with op.batch_alter_table("disaster_responses", recreate="always") as batch_op:
        batch_op.drop_constraint("fk_disaster_responses_relayed_by_user_id_users", type_="foreignkey")
        batch_op.drop_index("ix_disaster_responses_packet_id")
        batch_op.drop_column("relayed_by_user_id")
        batch_op.drop_column("hop_count")
        batch_op.drop_column("is_mesh_relayed")
        batch_op.drop_column("packet_id")
