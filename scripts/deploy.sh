#!/usr/bin/env bash
# One entry for the PulseDesk backend.
#
#   scripts/deploy.sh local              this machine (Docker if present, otherwise Homebrew Postgres + Redis)
#   scripts/deploy.sh remote user@host   same compose file on a Linux server
#   scripts/deploy.sh status
#   scripts/deploy.sh down
#
# Remote optional env: DEPLOY_DIR (default /opt/phosphor-terminal)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKEND="$ROOT/backend"
RUN_DIR="$ROOT/.run"
LOG_DIR="$ROOT/logs"
PID_FILE="$RUN_DIR/api.pid"
API_LOG="$LOG_DIR/api.log"
VENV="$ROOT/.venv"

DB_USER="${PULSEDESK_DB_USER:-pulsedesk}"
DB_PASSWORD="${PULSEDESK_DB_PASSWORD:-pulsedesk}"
DB_NAME="${PULSEDESK_DB_NAME:-pulsedesk}"
DB_HOST="${PULSEDESK_DB_HOST:-127.0.0.1}"
DB_PORT="${PULSEDESK_DB_PORT:-5432}"
REDIS_URL="${REDIS_URL:-redis://127.0.0.1:6379/0}"
DATABASE_URL="postgresql://${DB_USER}:${DB_PASSWORD}@${DB_HOST}:${DB_PORT}/${DB_NAME}"

mkdir -p "$RUN_DIR" "$LOG_DIR"

log() { printf '==> %s\n' "$*"; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

ensure_secrets() {
  # Compose reads the project-root .env for ${SECRET_KEY} / ${PULSEDESK_ENCRYPTION_KEY}.
  bash "$ROOT/scripts/gen-secrets.sh" "$ROOT/.env" '["localhost","127.0.0.1"]'
}

have_docker() {
  docker info >/dev/null 2>&1 && { docker compose version >/dev/null 2>&1 || docker-compose version >/dev/null 2>&1; }
}

compose() {
  if docker compose version >/dev/null 2>&1; then
    docker compose -f "$ROOT/docker-compose.yml" "$@"
  else
    docker-compose -f "$ROOT/docker-compose.yml" "$@"
  fi
}

api_pid() {
  if [[ -f "$PID_FILE" ]]; then
    local pid
    pid="$(cat "$PID_FILE")"
    if kill -0 "$pid" 2>/dev/null; then
      echo "$pid"
      return 0
    fi
  fi
  return 1
}

stop_api() {
  local pid
  if pid="$(api_pid)"; then
    log "stopping API pid $pid"
    kill "$pid" 2>/dev/null || true
    for _ in 1 2 3 4 5 6 7 8 9 10; do
      kill -0 "$pid" 2>/dev/null || break
      sleep 0.5
    done
    kill -9 "$pid" 2>/dev/null || true
  fi
  rm -f "$PID_FILE"
  # The earlier throwaway SQLite process also binds :8000.
  local occupant
  occupant="$(lsof -nP -tiTCP:8000 -sTCP:LISTEN 2>/dev/null || true)"
  if [[ -n "$occupant" ]]; then
    log "freeing port 8000 (pid $occupant)"
    kill $occupant 2>/dev/null || true
    sleep 0.5
  fi
}

write_env() {
  local env_file="$BACKEND/.env"
  if [[ -f "$env_file" ]]; then
    log "keeping existing $env_file"
    return
  fi
  cat >"$env_file" <<EOF
DATABASE_URL=${DATABASE_URL}
REDIS_URL=${REDIS_URL}
FREQTRADE_URL=http://127.0.0.1:8080
FREQTRADE_USERNAME=freqtrade
FREQTRADE_PASSWORD=freqtrade
CORS_ORIGINS=["http://localhost:5173","http://127.0.0.1:5173"]
LOG_LEVEL=INFO
LOG_FORMAT=json
LIVE_SMALL_ENABLED=false
EOF
  log "wrote $env_file"
}

ensure_venv() {
  if [[ ! -x "$VENV/bin/python" ]]; then
    log "creating virtualenv"
    python3 -m venv "$VENV"
    "$VENV/bin/pip" install -U pip
    "$VENV/bin/pip" install -r "$BACKEND/requirements.txt"
  fi
}

pg_bin() {
  local name
  for name in postgresql@16 postgresql@14 postgresql; do
    local prefix
    prefix="$(brew --prefix "$name" 2>/dev/null || true)"
    if [[ -n "$prefix" && -x "$prefix/bin/pg_isready" ]]; then
      echo "$prefix"
      return 0
    fi
  done
  die "PostgreSQL is installed but pg_isready was not found"
}

ensure_brew_services() {
  command -v brew >/dev/null 2>&1 || die "Homebrew is required for a local deploy without Docker"
  export HOMEBREW_NO_AUTO_UPDATE=1
  local formula=""
  if [[ -x "$(brew --prefix postgresql@16 2>/dev/null)/bin/pg_isready" ]]; then
    formula="postgresql@16"
  elif [[ -x "$(brew --prefix postgresql@14 2>/dev/null)/bin/pg_isready" ]]; then
    formula="postgresql@14"
  elif [[ -x "$(brew --prefix postgresql 2>/dev/null)/bin/pg_isready" ]]; then
    formula="postgresql"
  else
    log "installing PostgreSQL"
    brew install postgresql
    formula="postgresql"
  fi
  if ! brew list redis >/dev/null 2>&1; then
    log "installing Redis"
    brew install redis
  fi
  local prefix redis_bin
  prefix="$(pg_bin)"
  redis_bin="$(brew --prefix redis)/bin/redis-server"
  log "starting $formula and redis"
  if ! "$prefix/bin/pg_isready" -h "$DB_HOST" -p "$DB_PORT" >/dev/null 2>&1; then
    "$prefix/bin/pg_ctl" -D "$(brew --prefix)/var/postgres" -l "$LOG_DIR/postgres.log" start
  fi
  if ! "$redis_bin" --version >/dev/null 2>&1; then
    redis_bin="redis-server"
  fi
  if ! redis-cli ping 2>/dev/null | grep -q PONG; then
    "$redis_bin" "$(brew --prefix)/etc/redis.conf" --daemonize yes --logfile "$LOG_DIR/redis.log"
  fi
  local i
  for i in $(seq 1 30); do
    if "$prefix/bin/pg_isready" -h "$DB_HOST" -p "$DB_PORT" >/dev/null 2>&1 \
      && redis-cli ping 2>/dev/null | grep -q PONG; then
      return 0
    fi
    sleep 1
  done
  die "Postgres or Redis did not become ready. See $LOG_DIR/postgres.log and $LOG_DIR/redis.log"
}

ensure_database() {
  local prefix psql
  prefix="$(pg_bin)"
  psql="$prefix/bin/psql"
  "$psql" -h "$DB_HOST" -p "$DB_PORT" -d postgres -v ON_ERROR_STOP=1 <<SQL
DO \$\$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = '${DB_USER}') THEN
    CREATE ROLE ${DB_USER} LOGIN PASSWORD '${DB_PASSWORD}';
  END IF;
END
\$\$;
SQL
  if ! "$psql" -h "$DB_HOST" -p "$DB_PORT" -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname='${DB_NAME}'" | grep -q 1; then
    "$prefix/bin/createdb" -h "$DB_HOST" -p "$DB_PORT" -O "$DB_USER" "$DB_NAME"
  fi
  log "database ${DB_NAME} is ready"
}

migrate() {
  log "applying migrations"
  (
    cd "$BACKEND"
    "$VENV/bin/alembic" upgrade head
  )
}

TA_PREFIX="${TA_PREFIX:-$HOME/.local/ta-lib}"

ensure_talib() {
  if grep -q TA_ACCBANDS "$TA_PREFIX/include/ta-lib/ta_func.h" 2>/dev/null; then
    return 0
  fi
  log "building TA-Lib 0.6.4 (Homebrew 0.4.0 is too old for Freqtrade)"
  local src="/tmp/ta-lib-0.6.4-src.tar.gz"
  curl -fsSL -o "$src" https://github.com/TA-Lib/ta-lib/releases/download/v0.6.4/ta-lib-0.6.4-src.tar.gz
  rm -rf /tmp/ta-lib-0.6.4
  tar -xzf "$src" -C /tmp
  (
    cd /tmp/ta-lib-0.6.4
    ./configure --prefix="$TA_PREFIX"
    make -j4
    make install
  )
}

ensure_freqtrade() {
  ensure_talib
  if ! "$VENV/bin/python" -c "import freqtrade" >/dev/null 2>&1; then
    log "installing Freqtrade into the backend virtualenv"
    TA_INCLUDE_PATH="$TA_PREFIX/include" \
      TA_LIBRARY_PATH="$TA_PREFIX/lib" \
      "$VENV/bin/pip" install "freqtrade==2025.11"
  fi
}

FT_PID_FILE="$RUN_DIR/freqtrade.pid"
FT_LOG="$LOG_DIR/freqtrade.log"

stop_freqtrade() {
  if [[ -f "$FT_PID_FILE" ]]; then
    local pid
    pid="$(cat "$FT_PID_FILE")"
    if kill -0 "$pid" 2>/dev/null; then
      log "stopping Freqtrade pid $pid"
      kill "$pid" 2>/dev/null || true
      sleep 1
      kill -9 "$pid" 2>/dev/null || true
    fi
  fi
  rm -f "$FT_PID_FILE"
  local occupant
  occupant="$(lsof -nP -tiTCP:8080 -sTCP:LISTEN 2>/dev/null || true)"
  if [[ -n "$occupant" ]]; then
    log "freeing port 8080 (pid $occupant)"
    kill $occupant 2>/dev/null || true
    sleep 0.5
  fi
}

start_freqtrade() {
  ensure_freqtrade
  stop_freqtrade
  mkdir -p "$ROOT/freqtrade/user_data/logs"
  log "starting Freqtrade dry-run on :8080"
  (
    cd "$ROOT/freqtrade"
    PYTHONPATH="$BACKEND${PYTHONPATH:+:$PYTHONPATH}" \
      DYLD_LIBRARY_PATH="$TA_PREFIX/lib${DYLD_LIBRARY_PATH:+:$DYLD_LIBRARY_PATH}" \
      nohup "$VENV/bin/python" start.py trade \
        --config user_data/config.json \
        --strategy PulseDeskUniversalStrategy \
        --user-data-dir user_data \
        >>"$FT_LOG" 2>&1 &
    echo $! >"$FT_PID_FILE"
  )
  local i
  for i in $(seq 1 90); do
    if curl -fsS -o /dev/null --max-time 2 -u freqtrade:freqtrade "http://127.0.0.1:8080/api/v1/ping"; then
      log "Freqtrade dry-run is up (pid $(cat "$FT_PID_FILE"))"
      return 0
    fi
    local pid
    pid="$(cat "$FT_PID_FILE" 2>/dev/null || true)"
    if [[ -n "$pid" ]] && ! kill -0 "$pid" 2>/dev/null; then
      echo "----- freqtrade log -----" >&2
      tail -40 "$FT_LOG" >&2 || true
      die "Freqtrade exited during startup"
    fi
    sleep 1
  done
  tail -40 "$FT_LOG" >&2 || true
  die "Freqtrade did not answer /api/v1/ping"
}

start_api() {
  stop_api
  log "starting API on :8000"
  (
    cd "$BACKEND"
    DYLD_LIBRARY_PATH="$TA_PREFIX/lib${DYLD_LIBRARY_PATH:+:$DYLD_LIBRARY_PATH}" \
      nohup "$VENV/bin/python" run.py >>"$API_LOG" 2>&1 &
    echo $! >"$PID_FILE"
  )
  local i
  for i in $(seq 1 40); do
    if curl -fsS -o /dev/null --max-time 2 "http://127.0.0.1:8000/health"; then
      log "API is up (pid $(cat "$PID_FILE"))"
      return 0
    fi
    if ! api_pid >/dev/null; then
      echo "----- api log -----" >&2
      tail -40 "$API_LOG" >&2 || true
      die "API exited during startup"
    fi
    sleep 1
  done
  tail -40 "$API_LOG" >&2 || true
  die "API did not answer /health"
}

deploy_local_native() {
  ensure_brew_services
  ensure_database
  ensure_venv
  write_env
  bash "$ROOT/scripts/gen-secrets.sh" "$BACKEND/.env" '["localhost","127.0.0.1"]'
  migrate
  start_api
  start_freqtrade
  log "local backend is running"
  log "API       http://127.0.0.1:8000/docs"
  log "Freqtrade http://127.0.0.1:8080  (dry-run, live Binance prices, no real orders)"
  log "web UI    http://localhost:5173/"
}

deploy_local_docker() {
  log "Docker is available; starting the same compose stack used on a server"
  ensure_secrets
  (cd "$ROOT" && compose up -d --build)
  log "compose stack is up: API :8000, Postgres :5432, Redis :6379, Freqtrade :8080"
}

deploy_local() {
  if have_docker; then
    deploy_local_docker
  else
    log "Docker is not installed; using Homebrew Postgres and Redis"
    deploy_local_native
  fi
}

deploy_remote() {
  local target="${1:-}"
  [[ -n "$target" ]] || die "usage: scripts/deploy.sh remote user@host"
  local dest="${DEPLOY_DIR:-/opt/phosphor-terminal}"
  command -v rsync >/dev/null 2>&1 || die "rsync is required"
  log "syncing to ${target}:${dest}"
  ssh "$target" "mkdir -p '$dest'"
  rsync -az --delete \
    --exclude '.git/' \
    --exclude '.venv/' \
    --exclude 'node_modules/' \
    --exclude '.run/' \
    --exclude 'logs/' \
    --exclude 'backend/.env' \
    --exclude '__pycache__/' \
    --exclude 'macos-app/.build/' \
    --exclude 'web/dist/' \
    "$ROOT/" "${target}:${dest}/"
  log "ensuring server secrets"
  ssh "$target" "cd '$dest' && bash scripts/gen-secrets.sh .env"
  log "starting compose on ${target}"
  log "NOTE: set ALLOWED_HOSTS in ${dest}/.env to your real domain before exposing traffic"
  ssh "$target" "cd '$dest' && docker compose up -d --build"
  log "remote backend is up on ${target} (API port 8000)"
}

status() {
  if have_docker && compose ps >/dev/null 2>&1; then
    compose ps || true
  fi
  if api_pid >/dev/null; then
    log "native API pid $(api_pid)"
  else
    log "native API is not running"
  fi
  curl -fsS --max-time 2 "http://127.0.0.1:8000/health" && echo || log "nothing answering :8000/health"
  curl -fsS --max-time 5 "http://127.0.0.1:8000/readiness" && echo || log "readiness failed"
}

down() {
  stop_freqtrade
  stop_api
  if have_docker; then
    compose down || true
  fi
  log "backend stopped (Homebrew Postgres and Redis are left running)"
}

case "${1:-}" in
  local) deploy_local ;;
  remote) shift; deploy_remote "$@" ;;
  status) status ;;
  down) down ;;
  *)
    cat <<EOF
usage:
  scripts/deploy.sh local
  scripts/deploy.sh remote user@host
  scripts/deploy.sh status
  scripts/deploy.sh down
EOF
    exit 1
    ;;
esac
