#!/usr/bin/env bash


# shellcheck disable=SC1091
. "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

MODE="$(resolve_mode)"
KEEP="${BACKUP_KEEP:-10}"

mkdir -p "$BACKUP_DIR"
timestamp="$(date -u +%Y%m%d_%H%M%S)"
outfile="$BACKUP_DIR/${POSTGRES_DB}_${timestamp}.dump"
tmpfile="$outfile.part"

log "mode=$MODE  db=$POSTGRES_DB  ->  $outfile"
wait_for_db

pg_exec pg_dump -d "$POSTGRES_DB" -Fc -Z 6 --no-owner --no-privileges > "$tmpfile"

if [ "$MODE" = docker ]; then
  compose exec -T "$COMPOSE_SERVICE" pg_restore --list < "$tmpfile" >/dev/null
else
  pg_restore --list "$tmpfile" >/dev/null
fi

mv "$tmpfile" "$outfile"
sha256_write "$outfile"
ln -sfn "$(basename "$outfile")" "$BACKUP_DIR/latest.dump"

size="$(du -h "$outfile" | cut -f1)"
log "backup complete ($size)"
log "source row counts:"
db_summary "$POSTGRES_DB" | sed 's/^/    /' >&2

if [ "$KEEP" -gt 0 ]; then
  ls -1t "$BACKUP_DIR"/"${POSTGRES_DB}"_*.dump 2>/dev/null | tail -n +"$((KEEP + 1))" | while read -r old; do
    log "pruning $(basename "$old")"
    rm -f "$old" "$old.sha256"
  done
fi

echo "$outfile"
