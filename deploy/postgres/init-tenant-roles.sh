#!/bin/sh
# Creates the least-privilege roles used by the multi-tenant deployment.
# The API still connects as the owner until RLS is enabled table by table.
set -eu

APP_PASSWORD="${APP_DB_PASSWORD:-pulsedesk_app}"
WORKER_PASSWORD="${WORKER_DB_PASSWORD:-pulsedesk_worker}"

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<SQL
DO \$\$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'alphaloop_app') THEN
    CREATE ROLE alphaloop_app LOGIN PASSWORD '${APP_PASSWORD}' NOBYPASSRLS;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'alphaloop_worker') THEN
    CREATE ROLE alphaloop_worker LOGIN PASSWORD '${WORKER_PASSWORD}' BYPASSRLS;
  END IF;
END
\$\$;

GRANT CONNECT ON DATABASE "$POSTGRES_DB" TO alphaloop_app, alphaloop_worker;
GRANT USAGE ON SCHEMA public TO alphaloop_app, alphaloop_worker;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public
  TO alphaloop_app, alphaloop_worker;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public
  TO alphaloop_app, alphaloop_worker;

ALTER DEFAULT PRIVILEGES FOR ROLE "$POSTGRES_USER" IN SCHEMA public
  GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO alphaloop_app, alphaloop_worker;
ALTER DEFAULT PRIVILEGES FOR ROLE "$POSTGRES_USER" IN SCHEMA public
  GRANT USAGE, SELECT ON SEQUENCES TO alphaloop_app, alphaloop_worker;
SQL
