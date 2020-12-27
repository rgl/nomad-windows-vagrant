import os

# see https://www.postgresql.org/docs/13/libpq-pgpass.html
os.environ['PGPASSFILE'] = 'c:/pgadmin4/pgpass.conf'

DEFAULT_SERVER = '0.0.0.0'
UPGRADE_CHECK_ENABLED = False
MASTER_PASSWORD_REQUIRED = False
ENHANCED_COOKIE_PROTECTION = False

# see https://github.com/postgres/pgadmin4/blob/REL-4_29/web/config.py#L271-L279
CONSOLE_LOG_LEVEL = 10
