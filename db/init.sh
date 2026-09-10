#!/usr/bin/env bash
# Runs once inside the postgres container on first boot (empty data dir).
# The official entrypoint only executes files in the top level of
# /docker-entrypoint-initdb.d, so this script applies the subdirectories
# in a controlled order: migrations first, then seed data.
set -euo pipefail

run_dir() {
  local dir="$1"
  for f in "$dir"/*.sql; do
    [ -e "$f" ] || continue
    echo ">> applying $(basename "$f")"
    psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" -f "$f"
  done
}

run_dir /docker-entrypoint-initdb.d/migrations
run_dir /docker-entrypoint-initdb.d/seed
echo ">> database initialised"
