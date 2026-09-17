"""Add AppRating model

Revision ID: 1b8d8cae2acb
Revises: 9a1e0f5c2d3b
Create Date: 2026-09-17 18:02:22.633915

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '1b8d8cae2acb'
down_revision: Union[str, Sequence[str], None] = '9a1e0f5c2d3b'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        'app_ratings',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('user_id', sa.Integer(), nullable=True),
        sa.Column('rating', sa.Integer(), nullable=False),
        sa.Column('feedback', sa.Text(), nullable=True),
        sa.Column('created_at', sa.DateTime(), nullable=True),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_app_ratings_id'), 'app_ratings', ['id'], unique=False)


def downgrade() -> None:
    op.drop_index(op.f('ix_app_ratings_id'), table_name='app_ratings')
    op.drop_table('app_ratings')
