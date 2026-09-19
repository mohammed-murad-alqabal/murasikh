"""add payload to delayed responses

Revision ID: 9a1e0f5c2d3b
Revises: 6e29af63fcb2
Create Date: 2026-09-17
"""

from typing import Union
from collections.abc import Sequence

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql


revision: str = "9a1e0f5c2d3b"
down_revision: str | Sequence[str] | None = "6e29af63fcb2"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column(
        "delayed_responses",
        sa.Column(
            "payload",
            postgresql.JSONB(astext_type=sa.Text()),
            nullable=False,
            server_default=sa.text("'{}'::jsonb"),
        ),
    )
    op.alter_column("delayed_responses", "payload", server_default=None)


def downgrade() -> None:
    op.drop_column("delayed_responses", "payload")
