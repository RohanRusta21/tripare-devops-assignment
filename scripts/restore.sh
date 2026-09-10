#!/usr/bin/env bash

# shellcheck disable=SC1091
. "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

MODE="$(resolve_mode)"
dump="${1:-$BACKUP_DIR/latest.dump}"
target="${2:-${POSTGRES_DB}_restore}"

[ -e "$dump" ] || die "dump not found: $dump"
dump="$(cd "$(dirname "$dump")" && pwd)/$(basename "$dump")"
[ -L "$dump" ] && dump="$(dirname "$dump")/$(readlink "$dump")"


if [ -f "$dump.sha256" ]; then
  sha256_check "$dump" || die "checksum mismatch for $dump"
  log "checksum OK"
fi

log "mode=$MODE  dump=$(basename "$dump")  ->  database '$target'"
wait_for_db

if [ "$target" = "$POSTGRES_DB" ] && [ "${FORCE:-0}" != 1 ]; then
  read -r -p "This will DROP and recreate '$POSTGRES_DB'. Continue? [y/N] " ans
  [[ "$ans" =~ ^[Yy]$ ]] || die "aborted"
fi

admin_db="postgres"
log "recreating database '$target'"
pg_exec psql -d "$admin_db" -X -q -v ON_ERROR_STOP=1 \
  -c "DROP DATABASE IF EXISTS \"$target\" WITH (FORCE);" \
  -c "CREATE DATABASE \"$target\" OWNER \"$POSTGRES_USER\";"

log "restoring"
pg_exec pg_restore -d "$target" --no-owner --no-privileges --exit-on-error < "$dump"

log "restore complete - verification:"
{
  printf '%-16s %-45s %s\n' "" "restored ($target)" "source ($POSTGRES_DB)"
  paste -d'|' <(db_summary "$target") <(db_summary "$POSTGRES_DB" 2>/dev/null || echo "n/a") \
    | while IFS='|' read -r r s; do
        printf '%-16s %-45s %s\n' "${r%%:*}" "${r#*: }" "${s#*: }"
      done
} | sed 's/^/    /' >&2

count="$(pg_exec psql -d "$target" -X -At -c 'SELECT count(*) FROM hotel_bookings;')"
[ "$count" -gt 0 ] || die "restored hotel_bookings is empty"
pg_exec psql -d "$target" -X -At -c \
  "SELECT count(*) FROM hotel_bookings b JOIN booking_events e ON e.booking_id = b.id;" >/dev/null

log "OK - $count bookings restored into '$target'"
