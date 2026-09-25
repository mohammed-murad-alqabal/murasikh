"""Add check constraints for feedback, confidence and rating

Revision ID: ab7e165f3e1c
Revises: a1b2c3d4e5f6
Create Date: 2026-09-25 21:21:20.550415

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'ab7e165f3e1c'
down_revision: Union[str, Sequence[str], None] = 'a1b2c3d4e5f6'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.create_check_constraint('check_valid_feedback', 'interactions', 'user_feedback IN (-1, 0, 1)')
    op.create_check_constraint('check_confidence_range', 'interactions', 'emotion_confidence >= 0.0 AND emotion_confidence <= 1.0')
    op.create_check_constraint('check_valid_rating', 'app_ratings', 'rating >= 1 AND rating <= 5')


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_constraint('check_valid_rating', 'app_ratings', type_='check')
    op.drop_constraint('check_confidence_range', 'interactions', type_='check')
    op.drop_constraint('check_valid_feedback', 'interactions', type_='check')
    # ### end Alembic commands ###
