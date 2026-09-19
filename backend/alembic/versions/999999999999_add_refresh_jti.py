from alembic import op
import sqlalchemy as sa

revision = '999999999999'
down_revision = None
branch_labels = None
depends_on = None

def upgrade() -> None:
    op.add_column('users', sa.Column('refresh_jti', sa.String(length=36), nullable=True))

def downgrade() -> None:
    op.drop_column('users', 'refresh_jti')
