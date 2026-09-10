# DevOps Assessment — Terraform + Database Reliability

AWS infrastructure (ALB → ECS/Fargate → RDS) designed in Terraform with separate `dev` / `prod` environments, plus a local PostgreSQL setup with migrations, seed data, an optimised reporting query, and tested backup/restore scripts.

Nothing here requires an AWS account: Terraform is validated and planned offline, and everything database-related runs in Docker Compose.

## Repository layout

```
.
├── infra/
│   ├── modules/
│   │   ├── network/          # VPC, public/private subnets, IGW, NAT, routes
│   │   ├── ecs/              # ALB + SG, ECS cluster/task/service + SG, IAM, logs
│   │   └── rds/              # RDS PostgreSQL + SG (ingress from ECS SG only)
│   └── envs/
│       ├── dev/              # small, cheap, disposable
│       └── prod/             # HA, larger, protected
├── db/
│   ├── migrations/           # 001 schema, 002 indexes
│   ├── seed/                 # 300 bookings + event trail
│   ├── queries/              # EXPLAIN for the target query
│   └── init.sh               # runs migrations then seed on first container boot
├── scripts/
│   ├── backup.sh             # timestamped pg_dump -Fc + sha256 + retention
│   ├── restore.sh            # restore into a fresh DB and verify against source
│   └── _common.sh            # shared helpers (docker or host mode)
├── .github/workflows/terraform-plan.yml   # fmt / init / validate / plan → PR comment + artifact
├── docker-compose.yml                
└── .env.example
```

---

## Part 1–2: Terraform

### Architecture

```
                 ┌─────────────────────── VPC 10.x.0.0/16 ───────────────────────┐
                 │  public subnets (per AZ)          private subnets (per AZ)     │
Internet ──▶ ALB │  ┌─────────┐  ┌─────┐            ┌──────────────┐  ┌────────┐ │
   :80       SG  │  │   ALB   │  │ NAT │ ◀── egress │ ECS/Fargate  │  │  RDS   │ │
                 │  └────┬────┘  └─────┘            │   tasks SG   │─▶│  SG    │ │
                 │       └──────── :80 ────────────▶└──────────────┘  └────────┘ │
                 │                                    only ALB SG      only ECS SG│
                 └───────────────────────────────────────────────────────────────┘
```

Security group chain — no CIDR rules past the edge:

| SG | Ingress | Egress |
|---|---|---|
| `alb-sg` | 80/tcp from `0.0.0.0/0` | container port → `ecs-tasks-sg` only |
| `ecs-tasks-sg` | container port from `alb-sg` only | all (image pulls, CloudWatch, RDS via NAT) |
| `rds-sg` | 5432/tcp from `ecs-tasks-sg` only | none |

RDS is `publicly_accessible = false`, lives in the private subnet group, forces TLS (`rds.force_ssl = 1`), is encrypted at rest, and its master password is generated and rotated by RDS in Secrets Manager (`manage_master_user_password = true`) — no DB secret ever appears in tfvars, CI logs, or state. The ECS task gets the credential injected as a `secrets` entry, not a plain env var, and the execution role is scoped to that single secret ARN.

### Environment differences

| Setting | dev | prod |
|---|---|---|
| VPC CIDR / AZs | `10.10.0.0/16`, 2 AZs | `10.20.0.0/16`, 3 AZs |
| NAT gateways | 1 shared | 1 per AZ |
| Fargate task | 0.25 vCPU / 512 MiB, ×1, **Spot** | 1 vCPU / 2 GiB, ×3, on-demand |
| Container Insights / log retention | off / 7 d | on / 90 d |
| RDS instance | `db.t4g.micro`, 20→50 GiB | `db.m6g.large`, 100→500 GiB |
| Multi-AZ | no | yes |
| Backup retention | 1 day | 30 days |
| Deletion protection (RDS + ALB) | **false** | **true** |
| Final snapshot on destroy | skipped | taken |
| Performance Insights / Enhanced Monitoring | off | on / 60 s |
| State | `s3://hotel-terraform-state/envs/dev/` | `s3://hotel-terraform-state/envs/prod/` |

Both environments use the same three modules and the same root layout; only `terraform.tfvars` and `backend.tf` differ. State keys are separate with DynamoDB locking; in a real setup prod would live in its own account/bucket.

### Reviewing without an AWS account

```bash
cd infra/envs/dev          # or prod
terraform fmt -check -recursive ../..
terraform init -backend=false
terraform validate
AWS_ACCESS_KEY_ID=plan-only AWS_SECRET_ACCESS_KEY=plan-only \
  terraform plan -refresh=false -var plan_only=true
```

`-backend=false` skips the S3 state bucket. `plan_only=true` flips the provider's `skip_credentials_validation` / `skip_requesting_account_id` / `skip_metadata_api_check` flags so the dummy credentials are never sent to AWS. The variable defaults to `false`, so a real `apply` behaves normally. The modules deliberately use no AWS data sources (AZs are passed in explicitly) so the plan is fully computable offline.

---


## Part 4–5: Local database, seed data, indexing

### Prerequisites

Docker with Compose v2. `psql` on the host is optional — the scripts run everything inside the container.

### Start

```bash
cp .env.example .env      # optional, defaults are fine
docker compose up -d --wait
```

On the first boot of an empty volume, `db/init.sh` applies `db/migrations/*.sql` then `db/seed/*.sql` in order. Watch it happen with `docker compose logs -f postgres`. (`docker compose down -v && docker compose up -d --wait`).

### Verify

```bash
docker compose exec postgres psql -U hotel -d hotel -c "
  SELECT count(*)                                            AS bookings,
         count(DISTINCT city)                                AS cities,
         count(DISTINCT org_id)                              AS orgs,
         count(DISTINCT status)                              AS statuses,
         (SELECT count(*) FROM booking_events)               AS events,
         (SELECT count(DISTINCT booking_id) FROM booking_events) AS bookings_with_events
  FROM hotel_bookings;"
```

Expected: 300 bookings, 8 cities, 6 orgs, 6 statuses, ~500 events across ~200 bookings. Seed data is generated with `setseed()` so it is reproducible; `created_at` is spread over the last 120 days so roughly a quarter of the rows fall inside the query's 30-day window.

### Query optimisation

Target query:

```sql
SELECT org_id, status, COUNT(*), SUM(amount)
FROM hotel_bookings
WHERE city = 'delhi'
  AND created_at >= NOW() - INTERVAL '30 days'
GROUP BY org_id, status;
```

Index added in `db/migrations/002_indexes.sql`:

```sql
CREATE INDEX idx_hotel_bookings_city_created_at
    ON hotel_bookings (city, created_at DESC)
    INCLUDE (org_id, status, amount);
```

**Why this shape**

- **`city` first, `created_at` second.** The equality predicate goes first so the B-tree seeks directly to the `delhi` block; the range predicate goes second so the recent rows are one contiguous scan within that block. Reversing the order would force scanning every city's rows in the date range and filtering.
- **`INCLUDE (org_id, status, amount)`.** These are the only other columns the query touches (group keys + aggregate). Carrying them as non-key payload lets PostgreSQL answer the whole query from the index — an **Index Only Scan with `Heap Fetches: 0`** — without widening the searchable key or bloating the tree with columns that don't help selectivity.
- **Not a partial index on `city = 'delhi'`.** Tempting, but the same report is needed for every city; one composite index serves all of them. A partial index only pays off when a single value is queried disproportionately and the table is very large.
- **`DESC` on `created_at`** is free here and makes "latest N bookings in city X" queries a forward scan.


Expected plan (verified against the seed data):

```
HashAggregate
  Group Key: org_id, status
  ->  Index Only Scan using idx_hotel_bookings_city_created_at on hotel_bookings
        Index Cond: ((city = 'delhi'::text) AND (created_at >= (now() - '30 days'::interval)))
        Heap Fetches: 0
```

At 300 rows the planner may pick a seq scan on a cold table simply because everything fits in one page; the seed ends with `VACUUM ANALYZE` so the visibility map is set and the index-only path is chosen. On a realistic table size the difference is a few index pages read vs. a full table scan.

Two supporting indexes are also created: `booking_events (booking_id, created_at)` for the FK and "history of a booking" lookups, and `hotel_bookings (org_id, status)` for the per-org dashboard access path.

---

## Part 6: Backup and restore

```bash
./scripts/backup.sh                      # -> backups/hotel_YYYYMMDD_HHMMSS.dump (+ .sha256, latest.dump symlink)
./scripts/restore.sh                     # latest dump -> fresh database 'hotel_restore'
./scripts/restore.sh backups/hotel_20260909_143000.dump          # specific dump
FORCE=1 ./scripts/restore.sh backups/latest.dump hotel           # overwrite the original DB (prompts unless FORCE=1)
```

**backup.sh** dumps in `pg_dump` custom format (compressed, selectively/parallel restorable), writes to a `.part` file and only renames it on success so an interrupted run never leaves a plausible-looking truncated backup, validates the archive with `pg_restore --list`, writes a SHA-256 sidecar, updates `latest.dump`, and prunes to the last 10 dumps (`BACKUP_KEEP`). Dumps land in `./backups/` on the host so they survive `docker compose down -v`.

**restore.sh** verifies the checksum, **drops and recreates** the target database (fresh, not a merge), runs `pg_restore --exit-on-error`, then prints a side-by-side verification against the live source.

### How to verify the restore worked

The script does this for you and exits non-zero if anything is off. Example output:

```
[15:51:51] checksum OK
[15:51:51] recreating database 'hotel_restore'
[15:51:51] restoring
[15:51:51] restore complete - verification:
                     restored (hotel_restore)                      source (hotel)
    hotel_bookings   300                                           300
    booking_events   517                                           517
    indexes          5                                             5
    checksum         7dc118486c9fee6910f280d9d76d1421              7dc118486c9fee6910f280d9d76d1421
[15:51:51] OK - 300 bookings restored into 'hotel_restore'
```

What is being checked:

1. **Row counts** for both tables match the source.
2. **Index count** matches — schema objects came across, not just data.
3. **Checksum** — `md5(string_agg(id ORDER BY id))` over every booking id is identical, i.e. the same rows, not just the same number of them.
4. A real join query runs against the restored DB (FKs and both tables are usable), and the script fails if `hotel_bookings` is empty.

To confirm the restore is a genuine restore and not the live database, break the source first:

```bash
./scripts/backup.sh
docker compose exec postgres psql -U hotel -d hotel -c "DELETE FROM hotel_bookings WHERE city = 'delhi';"
./scripts/restore.sh               # restored side shows 300, source side shows fewer
FORCE=1 ./scripts/restore.sh backups/latest.dump hotel    # put the original back
```

Both scripts auto-detect whether to run through `docker compose exec` or host `pg_dump`/`pg_restore` (`PG_MODE=docker|local|auto`), so the same scripts work against the compose stack or any reachable PostgreSQL via the standard `PG*` environment variables.

Checksumming is likewise platform-agnostic: `_common.sh` uses `sha256sum` (coreutils) where available and falls back to `shasum -a 256` or `openssl dgst`, so the scripts run unmodified on macOS, where coreutils is not installed by default. The sidecar format is identical either way, so a dump taken on Linux verifies on macOS and vice versa.

---

## Notes and assumptions

- Region is `ap-south-1`; change `region` and `availability_zones` in the tfvars for another region.
- The application container is `public.ecr.aws/nginx/nginx:1.27-alpine` (public ECR avoids Docker Hub rate limits from Fargate). `container_image` / `container_port` / `health_check_path` are variables.
- The ALB listener is HTTP-only because no domain or certificate is in scope. Adding HTTPS is a listener + ACM cert + 80→443 redirect in `modules/ecs`.
- `terraform.lock.hcl` is intentionally not committed since providers were not initialised against a live registry here; the first `terraform init` in your environment will create it and it should then be committed.
- Local database credentials in `.env.example` are development-only placeholders.
