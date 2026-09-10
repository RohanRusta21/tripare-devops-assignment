#!/usr/bin/env bash


set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKUP_DIR="${BACKUP_DIR:-$REPO_ROOT/backups}"

if [ -f "$REPO_ROOT/.env" ]; then
  set -a
  # shellcheck disable=SC1091
  . "$REPO_ROOT/.env"
  set +a
fi

POSTGRES_DB="${POSTGRES_DB:-hotel}"
POSTGRES_USER="${POSTGRES_USER:-hotel}"
COMPOSE_SERVICE="${COMPOSE_SERVICE:-postgres}"

PG_MODE="${PG_MODE:-auto}"

log()  { printf '\033[1;34m[%s]\033[0m %s\n' "$(date +%H:%M:%S)" "$*" >&2; }
die()  { printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }

compose() { (cd "$REPO_ROOT" && docker compose "$@"); }

resolve_mode() {
  case "$PG_MODE" in
    docker|local) echo "$PG_MODE" ;;
    auto)
      if command -v docker >/dev/null 2>&1 \
         && [ -n "$(compose ps -q "$COMPOSE_SERVICE" 2>/dev/null)" ]; then
        echo docker
      elif command -v pg_dump >/dev/null 2>&1; then
        echo local
      else
        die "Neither a running compose service '$COMPOSE_SERVICE' nor local pg tools found."
      fi ;;
    *) die "PG_MODE must be auto, docker or local (got '$PG_MODE')" ;;
  esac
}

pg_exec() {
  local tool="$1"; shift
  if [ "$MODE" = docker ]; then
    compose exec -T -e PGPASSWORD="${POSTGRES_PASSWORD:-}" "$COMPOSE_SERVICE" "$tool" -U "$POSTGRES_USER" "$@"
  else
    "$tool" -U "$POSTGRES_USER" "$@"
  fi
}

wait_for_db() {
  local tries=30
  until pg_exec pg_isready -d "$POSTGRES_DB" >/dev/null 2>&1; do
    tries=$((tries - 1))
    [ "$tries" -gt 0 ] || die "database not ready after 30 attempts"
    sleep 1
  done
}

# SHA-256 differs per platform: coreutils ships sha256sum, macOS/BSD ship
# shasum. Both write and verify the same "<hash>  <file>" sidecar format, so a
# dump checksummed on one host verifies on the other.
sha256_tool() {
  if command -v sha256sum >/dev/null 2>&1;   then echo sha256sum
  elif command -v shasum >/dev/null 2>&1;    then echo shasum
  elif command -v openssl >/dev/null 2>&1;   then echo openssl
  else die "no SHA-256 tool found (need sha256sum, shasum or openssl)"
  fi
}

# Write <file>.sha256 next to the dump, recording the basename so the sidecar
# stays valid if the backups directory is moved or copied elsewhere.
sha256_write() {
  local dir base
  dir="$(dirname "$1")"; base="$(basename "$1")"
  case "$(sha256_tool)" in
    sha256sum) (cd "$dir" && sha256sum "$base" > "$base.sha256") ;;
    shasum)    (cd "$dir" && shasum -a 256 "$base" > "$base.sha256") ;;
    openssl)   (cd "$dir" && printf '%s  %s\n' \
                  "$(openssl dgst -sha256 "$base" | awk '{print $NF}')" \
                  "$base" > "$base.sha256") ;;
  esac
}

sha256_check() {
  local dir base expected actual
  dir="$(dirname "$1")"; base="$(basename "$1")"
  case "$(sha256_tool)" in
    sha256sum) (cd "$dir" && sha256sum -c --quiet "$base.sha256") ;;
    shasum)    (cd "$dir" && shasum -a 256 -c --quiet "$base.sha256") ;;
    openssl)
      expected="$(awk '{print $1; exit}' "$dir/$base.sha256")"
      actual="$(openssl dgst -sha256 "$1" | awk '{print $NF}')"
      [ "$expected" = "$actual" ] ;;
  esac
}

db_summary() {
  local db="$1"
  pg_exec psql -d "$db" -X -At -c "
    SELECT 'hotel_bookings: ' || count(*) FROM hotel_bookings
    UNION ALL SELECT 'booking_events: ' || count(*) FROM booking_events
    UNION ALL SELECT 'indexes: ' || count(*) FROM pg_indexes WHERE schemaname = 'public'
    UNION ALL SELECT 'checksum: ' || md5(string_agg(id::text, ',' ORDER BY id)) FROM hotel_bookings;"
}
