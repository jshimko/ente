# CLAUDE.md — Museum (Ente API Server)

Go API server powering all Ente clients (Photos, Auth, Locker). Handles authentication, E2EE key management, file metadata, billing, and multi-datacenter object replication.

**Documented:** 2026-05-18
**Commit:** 1a73928e4f

---

## Directory Structure

```sh
server/
├── cmd/museum/main.go         # Entry point: config, DB, routing, cron jobs (~1,406 lines)
├── ente/                      # Domain models & entities (pure data, no I/O)
│   ├── user.go, file.go, collection.go, billing.go, errors.go, app.go, ...
│   ├── legacy_kit.go          # Legacy crypto kit recovery models
│   ├── passkeyCredential.go, webauthnSession.go  # WebAuthn data structures
│   ├── anonymous_identity.go, access.go, kex.go, file_link.go, memory_share_expiry.go
│   ├── jwt/                   # JWT claim types (PAYMENT, FAMILIES, ACCOUNTS)
│   ├── cache/                 # User cache structures
│   ├── cast/                  # Chromecast models
│   ├── contact/               # Contact entity, attachment types and policies
│   ├── data_cleanup/          # Data cleanup models
│   ├── details/               # User details and Locker usage models
│   ├── social/                # Comments, reactions, anonymous users
│   ├── storagebonus/          # Referral/bonus models
│   ├── filedata/              # File data models
│   └── base/                  # Request ID generation, base utilities
├── pkg/
│   ├── api/                   # HTTP handlers (request parsing, response writing)
│   │   ├── legacy_kit.go      # Legacy crypto kit recovery handler
│   │   ├── public_comments.go # Public-link comments handler
│   │   ├── diff_utils.go      # Shared diff/pagination helpers
│   │   └── ...                # + domain handlers (see Core API Domains)
│   ├── controller/            # Business logic (orchestrates repos + external services)
│   │   ├── access/            # Access control logic
│   │   ├── commonbilling/     # Common billing controller
│   │   ├── data_cleanup/      # User data cleanup
│   │   ├── email/             # Email notification controller
│   │   ├── file_copy/         # File copy operations
│   │   ├── contact/           # Contact lifecycle, attachment replication/deletion
│   │   ├── legacy_kit/        # Shamir-style recovery for legacy backup keys
│   │   ├── lock/              # Distributed lock controller
│   │   ├── usercache/         # User cache controller
│   │   ├── file_meta.go       # File metadata operations
│   │   ├── trash_file_metadata.go # Trash metadata cleanup
│   │   ├── mailing_lists.go   # Listmonk/Zoho list orchestration
│   │   └── ...                # + domain-specific dirs/files (see Core API Domains)
│   ├── repo/                  # Data access (raw SQL queries via database/sql)
│   │   ├── public/            # Public access repos (collection links, file links, paste, device tokens)
│   │   ├── datacleanup/       # Data cleanup repo
│   │   ├── contact/           # Contact data access
│   │   ├── legacy_kit/        # Legacy kit storage
│   │   ├── two_factor_recovery/ # 2FA recovery repo
│   │   ├── notificationhistory.go # Deduped notification log
│   │   ├── collection_files.go, file_size.go  # Specialized file queries
│   │   └── ...                # + domain-specific dirs/files (see Core API Domains)
│   ├── middleware/             # Auth, rate limiting, CORS, logging, panic recovery
│   ├── utils/                 # Shared utilities
│   │   ├── config/            # Viper configuration loader
│   │   ├── auth/              # Token extraction, password hashing, random generation
│   │   ├── billing/           # Plan definitions, Stripe client setup
│   │   ├── crypto/            # XSalsa20-Poly1305 encrypt/decrypt, BLAKE2b hashing
│   │   ├── email/             # SMTP & Transmail (Zoho) email sending
│   │   ├── handler/           # Error-to-HTTP-status mapping, response helpers
│   │   ├── s3config/          # Multi-datacenter S3 client setup
│   │   ├── byteMarshaller/    # Byte/Base64 marshalling utilities
│   │   ├── file/              # File utilities
│   │   ├── rollout/           # Feature rollout percentage logic
│   │   └── time/, string/, array/, network/, random/, recover/
│   └── external/              # External service clients (Wasabi, Zoho, Listmonk)
│       ├── wasabi/            # Wasabi compliance hold management
│       ├── zoho/              # Zoho Zeptomail email API
│       └── listmonk/          # Listmonk email marketing API
├── migrations/                # 122 PostgreSQL migrations, 244 files with up/down (golang-migrate)
├── configurations/            # Environment YAML configs
│   ├── base.yaml              # Base config (establishes key hierarchy)
│   ├── local.yaml             # Dev defaults (port 8080, MinIO, stdout logging)
│   └── production.yaml        # Prod overrides (TLS, file logging)
├── mail-templates/            # 35 email templates (HTML files + subdirectories)
├── web-templates/             # HTML templates for server-rendered pages
├── tools/                     # Standalone utilities (key generation, S3 cleanup)
├── scripts/                   # Deployment & test scripts
├── compose.yaml               # Docker dev cluster (Museum + Postgres + MinIO)
├── compose.test.yaml          # Docker test cluster
├── Dockerfile                 # Multi-stage build (configurable via ARGs, defaults golang:1.26.1-alpine3.23 → alpine:3.23)
└── go.mod                     # Go 1.23, 39 direct dependencies
```

---

## Architecture

```
HTTP Request
  │
  ├─ Middleware: requestid → logger → CORS → gzip → panic-recover
  │
  ├─ Route Group Middleware: rate-limiter → auth (token/JWT/public-access)
  │
  ▼
pkg/api/         Handlers — parse request, call controller, write response
  │
  ▼
pkg/controller/  Controllers — business logic, orchestrate repos + services
  │
  ▼
pkg/repo/        Repositories — raw SQL via database/sql, transactions
  │
  ▼
PostgreSQL       Metadata, encrypted keys, subscriptions
S3 (3 DCs)       Encrypted file data (B2, Wasabi, Scaleway)
```

**No ORM** — all queries are hand-written SQL.
**Dependency injection** — repos/controllers/handlers constructed in `main.go` and passed by struct fields.

---

## Quick Navigation

| To find...                    | Look in...                                                 |
| ----------------------------- | ---------------------------------------------------------- |
| All HTTP routes               | `cmd/museum/main.go:523-1040` (route registration)         |
| A specific API handler        | `pkg/api/<domain>.go`                                      |
| Business logic for a feature  | `pkg/controller/<domain>.go` or `pkg/controller/<domain>/` |
| Database queries              | `pkg/repo/<domain>.go` or `pkg/repo/<domain>/`             |
| Domain model / request types  | `ente/<domain>.go`                                         |
| Error definitions             | `ente/errors.go`                                           |
| Error → HTTP status mapping   | `pkg/utils/handler/handler.go`                             |
| Auth middleware (token/JWT)   | `pkg/middleware/auth.go`                                   |
| Cast auth middleware          | `pkg/middleware/cast_auth.go`                              |
| Collection link middleware    | `pkg/middleware/collection_link.go`                        |
| File link middleware          | `pkg/middleware/file_link.go`                              |
| Memory share middleware       | `pkg/middleware/memory_share.go`                           |
| Rate limiting                 | `pkg/middleware/rate_limit.go`                             |
| Panic recovery                | `pkg/middleware/recover.go`                                |
| Request logging + metrics     | `pkg/middleware/request_logger.go`                         |
| Configuration loading         | `pkg/utils/config/config.go`                               |
| S3 multi-DC setup             | `pkg/utils/s3config/s3config.go`                           |
| Crypto (encrypt/decrypt/hash) | `pkg/utils/crypto/`                                        |
| Email sending                 | `pkg/utils/email/email.go`                                 |
| Billing plan definitions      | `pkg/utils/billing/`                                       |
| DB migrations                 | `migrations/{number}_{name}.up.sql`                        |
| Cron job schedules            | `cmd/museum/main.go:1210-1320`                             |
| Background workers setup      | `cmd/museum/main.go:1159-1187`                             |
| Docker dev environment        | `compose.yaml`                                             |
| Dev config defaults           | `configurations/local.yaml`                                |
| Email HTML templates          | `mail-templates/`                                          |

---

## Route Groups & Authentication

All routes registered in `cmd/museum/main.go`. Ten route groups with different auth:

| Group                 | Path Prefix          | Auth Method           | Middleware                             |
| --------------------- | -------------------- | --------------------- | -------------------------------------- |
| `publicAPI`           | `/`                  | None                  | Global rate limit + per-API rate limit |
| `privateAPI`          | `/`                  | `X-Auth-Token` header | Token auth + per-user rate limit       |
| `adminAPI`            | `/admin`             | Token + admin check   | Token auth + admin middleware          |
| `paymentJwtAuthAPI`   | `/`                  | JWT (PAYMENT scope)   | JWT token validation                   |
| `familiesJwtAuthAPI`  | `/`                  | JWT (FAMILIES scope)  | JWT + per-user rate limit              |
| `accountsJwtAuthAPI`  | `/`                  | JWT (ACCOUNTS scope)  | JWT token validation                   |
| `publicCollectionAPI` | `/public-collection` | `X-Auth-Access-Token` | Collection link middleware             |
| `fileLinkApi`         | `/file-link`         | `X-Auth-Access-Token` | File link middleware                   |
| `publicMemoryAPI`     | `/public-memory`     | `X-Auth-Access-Token` | Memory share middleware                |
| `castAPI`             | `/cast`              | Cast-specific         | Cast auth middleware                   |

**Token extraction** (`pkg/utils/auth/auth.go`):

- `X-Auth-Token` header or `token` query param → standard auth
- `X-Auth-Access-Token` header or `accessToken` query param → public access
- `X-Cast-Access-Token` header or `castToken` query param → cast device

**App detection**: `X-Client-Package` header → `io.ente.auth` (Auth), `io.ente.locker` (Locker), default (Photos)

---

## Core API Domains

### Users & Auth

| Layer      | File                                       |
| ---------- | ------------------------------------------ |
| Handler    | `pkg/api/user.go`                          |
| Controller | `pkg/controller/user/`                     |
| Repo       | `pkg/repo/user.go`, `pkg/repo/userauth.go` |
| Models     | `ente/user.go`                             |

Key endpoints: `/users/ott` (send OTP), `/users/verify-email`, `/users/srp/*` (SRP auth), `/users/two-factor/*`, `/users/change-email`

### Files

| Layer      | File                                                 |
| ---------- | ---------------------------------------------------- |
| Handler    | `pkg/api/file.go`, `pkg/api/file_data.go`            |
| Controller | `pkg/controller/file.go`, `pkg/controller/filedata/` |
| Repo       | `pkg/repo/file.go`, `pkg/repo/filedata/`             |
| Models     | `ente/file.go`                                       |

Key endpoints: `/files/upload-urls`, `/files/download/:fileID`, `/files/preview/:fileID`, `/files` (create/update)

### Collections

| Layer      | File                          |
| ---------- | ----------------------------- |
| Handler    | `pkg/api/collection.go`       |
| Controller | `pkg/controller/collections/` |
| Repo       | `pkg/repo/collection.go`      |
| Models     | `ente/collection.go`          |

Key endpoints: `/collections` (CRUD), `/collections/share`, `/collections/sharees`, `/collections/v2`, `/collections/v3`

### Billing

| Layer      | File                                                                                                                 |
| ---------- | -------------------------------------------------------------------------------------------------------------------- |
| Handler    | `pkg/api/billing.go`                                                                                                 |
| Controller | `pkg/controller/billing.go`, `pkg/controller/stripe.go`, `pkg/controller/appstore.go`, `pkg/controller/playstore.go` |
| Repo       | `pkg/repo/billing.go`                                                                                                |
| Models     | `ente/billing.go`                                                                                                    |

Three payment providers: Stripe (US/India), Apple IAP, Google Play. Unified through `CommonBillingController`.

### Trash

| Layer      | File                      |
| ---------- | ------------------------- |
| Handler    | `pkg/api/trash.go`        |
| Controller | `pkg/controller/trash.go` |
| Repo       | `pkg/repo/trash.go`       |

### Public Sharing

- **Public collections**: `pkg/api/public_collection.go`, `pkg/controller/public/`
- **File links**: `pkg/api/file_link.go`, `pkg/controller/public/file_link.go`
- **Memory shares**: `pkg/api/memory_share.go`, `pkg/api/public_memory_share.go`, `pkg/controller/memory_share/`
- **Public comments**: `pkg/api/public_comments.go` paired with `pkg/controller/public/CommentsController`
- **Browser device tokens**: `pkg/controller/public/link_device_token.go` issues a per-device JWT (`LinkDeviceClaim`) that public collection / file / memory endpoints require alongside `X-Auth-Access-Token`. Free users are capped via the `device_limit` columns on the public-token tables (default 5). Validated in `pkg/middleware/collection_link.go`, `file_link.go`, and `memory_share.go`.

### Legacy Kit (Crypto Recovery)

| Layer      | File                          |
| ---------- | ----------------------------- |
| Handler    | `pkg/api/legacy_kit.go`       |
| Controller | `pkg/controller/legacy_kit/`  |
| Repo       | `pkg/repo/legacy_kit/`        |
| Models     | `ente/legacy_kit.go`          |

Shamir-style recovery for legacy backup keys. Owners upload encrypted recovery kits; trustees can recover after a configurable notice period. Status machine: `WAITING → READY → RECOVERED`, with `BLOCKED` / `CANCELLED` branches. Stored in the `legacy_kits` table.

Key endpoints:
- Owner (`privateAPI`): `POST /legacy-kits`, `GET /legacy-kits`, `DELETE /legacy-kits/:id`, `GET /legacy-kits/:id/download-content`, `GET /legacy-kits/:id/recovery-session`, `POST /legacy-kits/update-recovery-notice`, `POST /legacy-kits/block-recovery`
- Trustee recovery (`publicAPI`): `POST /legacy-kits/recovery/{challenge,open,session,info,init-change-password}`

### Social (Comments & Reactions)

| Layer      | File                                                               |
| ---------- | ------------------------------------------------------------------ |
| Handler    | `pkg/api/comments.go`, `pkg/api/reactions.go`, `pkg/api/social.go` |
| Controller | `pkg/controller/social/`                                           |
| Repo       | `pkg/repo/social/`                                                 |
| Models     | `ente/social/`                                                     |

### Contacts

| Layer      | File                      |
| ---------- | ------------------------- |
| Handler    | `pkg/api/contact.go`      |
| Controller | `pkg/controller/contact/` |
| Repo       | `pkg/repo/contact/`       |
| Models     | `ente/contact/`           |

Key endpoints: `/contacts` (CRUD), `/contacts/diff`, `/contacts/:id/attachments/:type`, `/contacts/:id/profile-picture`, `/attachments/:type/upload-url`, `/attachments/:type/:attachmentID`

Contacts support E2EE attachments (profile pictures) with multi-datacenter replication via the `user_attachments` table. Attachment blobs are stored in S3 alongside regular file objects.

### Other Domains

| Domain                       | Handler                                         | Controller                                                | Repo                                                          |
| ---------------------------- | ----------------------------------------------- | --------------------------------------------------------- | ------------------------------------------------------------- |
| Family plans                 | `pkg/api/family.go`                             | `pkg/controller/family/`                                  | `pkg/repo/family.go`                                          |
| Emergency contacts           | `pkg/api/emergency.go`                          | `pkg/controller/emergency/`                               | `pkg/repo/emergency/`                                         |
| Authenticator (2FA app)      | `pkg/api/authenticator.go`                      | `pkg/controller/authenticator/`                           | `pkg/repo/authenticator/`                                     |
| Passkeys (WebAuthn)          | `pkg/api/passkeys.go`                           | `pkg/controller/passkeys.go`                              | `pkg/repo/passkey/`                                           |
| Cast (Chromecast)            | `pkg/api/cast.go`                               | `pkg/controller/cast/`                                    | `pkg/repo/cast/`                                              |
| Storage bonuses              | `pkg/api/storage_bonus.go`                      | `pkg/controller/storagebonus/`                            | `pkg/repo/storagebonus/`                                      |
| Remote store (feature flags) | `pkg/api/remotestore.go`                        | `pkg/controller/remotestore/`                             | `pkg/repo/remotestore/`                                       |
| User entities                | `pkg/api/userentity.go`                         | `pkg/controller/userentity/`                              | `pkg/repo/userentity/`                                        |
| Paste                        | `pkg/api/paste.go`                              | —                                                         | `pkg/repo/public/paste.go`                                    |
| Offers/Discounts             | `pkg/api/offer.go`, `pkg/api/discountcoupon.go` | `pkg/controller/offer/`, `pkg/controller/discountcoupon/` | `pkg/repo/discountcoupon/`                                    |
| Embeddings (ML)              | —                                               | `pkg/controller/embedding/`                               | `pkg/repo/embedding/`                                         |
| Push notifications           | `pkg/api/push.go`                               | `pkg/controller/push.go`                                  | `pkg/repo/push.go`                                            |
| Admin                        | `pkg/api/admin.go`, `pkg/api/admin_listmonk.go` | —                                                         | —                                                             |
| Collection actions           | `pkg/api/collection_actions.go`                 | `pkg/controller/collection_actions.go`                    | `pkg/repo/collection_actions.go`                              |
| Data cleanup                 | —                                               | `pkg/controller/data_cleanup/`                            | `pkg/repo/datacleanup/`                                       |
| Object storage               | —                                               | `pkg/controller/object.go`, `object_cleanup.go`           | `pkg/repo/object.go`, `object_cleanup.go`, `object_copies.go` |
| Replication                  | —                                               | `pkg/controller/replication3.go`                          | —                                                             |
| Usage tracking               | —                                               | `pkg/controller/usage.go`                                 | `pkg/repo/usage.go`                                           |
| Health check                 | `pkg/api/healthcheck.go`                        | —                                                         | —                                                             |

---

## Configuration System

**Library:** Viper (`github.com/spf13/viper`)
**Loader:** `pkg/utils/config/config.go`

### Load order (later overrides earlier)

1. `configurations/base.yaml` (establishes key hierarchy)
2. `configurations/{ENVIRONMENT}.yaml` (default: `local.yaml`, set via `ENVIRONMENT` env var)
3. `credentials.yaml` (or path from `ENTE_CREDENTIALS_FILE`)
4. `museum.yaml` (gitignored local overrides)
5. Environment variables (highest priority)

### Environment variable pattern

```
YAML path          → Env var
db.host            → ENTE_DB_HOST
s3.b2-eu-cen.key  → ENTE_S3_B2_EU_CEN_KEY
key.encryption     → ENTE_KEY_ENCRYPTION
```

Prefix `ENTE_`, uppercase, replace `.` and `-` with `_`.

### Key config sections

| Section                         | Purpose                                                           |
| ------------------------------- | ----------------------------------------------------------------- |
| `db.*`                          | PostgreSQL connection (host, port, name, user, password, sslmode) |
| `s3.*`                          | S3 bucket configs per datacenter (`b2-eu-cen`, `wasabi-eu-central-2-v3`, `scw-eu-fr-v3`, plus `wasabi-eu-central-2-derived` for derived data; `hot_storage`, `file-data-config`, `attachment-config` subsections route hot data, file-data blobs, and contact attachments to primary/secondary buckets) |
| `key.encryption`                | Base64 key for encrypting user emails at rest                     |
| `key.hash`                      | Base64 key for hashing emails (lookups)                           |
| `jwt.secret`                    | JWT signing secret                                                |
| `smtp.*`                        | SMTP email credentials                                            |
| `transmail.*`                   | Zoho Zeptomail credentials                                        |
| `stripe.*`                      | Stripe API keys (per US/India account)                            |
| `apple.shared-secret`           | Apple IAP validation                                              |
| `webauthn.*`                    | WebAuthn relying party config (`rpid`, `rporigins`, plus `legacy-rpid` / `legacy-rporigins` for the ente.io → ente.com RPID migration) |
| `discord.*`                     | Discord bot for devops alerts                                     |
| `internal.admins`               | Admin user ID list                                                |
| `internal.silent`               | Suppress Discord notifications                                    |
| `internal.disable-registration` | Block new signups                                                 |
| `internal.hardcoded-ott.*`      | Fixed OTP for testing                                             |
| `apps.*`                        | External app URLs (`public-albums`, `embed-albums`, `public-locker`, `public-paste`, `cast`, `accounts`, `accounts-legacy`, `family`, `public-memories`, `legacy`, `custom-domain`) |
| `jobs.cron.skip`                | Disable all cron jobs                                             |
| `replication.*`                 | Multi-DC replication config                                       |
| `log-file`                      | Log file path (production)                                        |
| `http.tls.*`                    | TLS certificate paths                                             |

---

## Database

**Engine:** PostgreSQL 15
**Driver:** `github.com/lib/pq`
**Migrations:** `golang-migrate/migrate/v4` — 122 migrations (244 files with up/down) in `migrations/`
**Connection pool:** 6 idle, 45 max open, 30min lifetime, 10min idle timeout

### Migration pattern

```
migrations/1_create_tables.up.sql
migrations/1_create_tables.down.sql
...
migrations/122_*.up.sql
```

Migrations run automatically on startup in `setupDatabase()`.

### Transaction pattern

```go
tx, err := repo.DB.BeginTx(ctx, nil)
if err != nil { return err }
defer tx.Rollback()
// ... execute queries on tx ...
return tx.Commit()
```

### Key tables

| Table               | Purpose                                      |
| ------------------- | -------------------------------------------- |
| `users`             | User accounts (email encrypted at rest)      |
| `key_attributes`    | Encrypted master key material, public keys   |
| `tokens`            | Session tokens                               |
| `otts`              | One-time tokens (email OTP)                  |
| `files`             | Encrypted file metadata                      |
| `collections`       | Albums/folders                               |
| `collection_shares` | E2EE sharing between users                   |
| `objects`           | S3 object references (key, size, datacenter) |
| `object_cleanup`    | Queued S3 deletions                          |
| `trash`             | Soft-deleted files                           |
| `subscriptions`     | Payment subscriptions (Stripe/Apple/Google)  |
| `two_factor`        | 2FA secrets and sessions                     |
| `passkeys`          | WebAuthn credentials                         |
| `families`          | Family plan memberships                      |
| `queue`             | Background job queue (DB-backed)             |
| `task_lock`         | Distributed cron job locking                 |
| `push_tokens`       | Firebase FCM device tokens                   |
| `memory_shares`     | Public memory share metadata                 |
| `embeddings`        | ML embedding vectors                         |
| `contact_entity`    | E2EE contact entries (per-user address book) |
| `user_attachments`  | Contact attachment blobs (profile pictures)  |
| `legacy_kits`        | Encrypted recovery kits + Shamir shares for legacy backup keys |
| `passkey_rp_ids`     | Per-credential RPID tracking for ente.io → ente.com migration |
| `notification_history` | Deduped email-notification log (storage warnings, etc.)    |

---

## Background Jobs & Cron

**Scheduler:** `github.com/robfig/cron/v3`
**Setup:** `cmd/museum/main.go` — `setupAndStartCrons()`
**Disable all:** Set `jobs.cron.skip: true` in config

### Cron schedule

| Interval | Job                                                   | Component                                            |
| -------- | ----------------------------------------------------- | ---------------------------------------------------- |
| 1m       | Remove expired OTTs                                   | `UserAuthRepository`                                 |
| 1m       | Remove expired 2FA sessions + used OTP codes          | `TwoFactorRepository`                                |
| 1m       | Remove expired temp 2FA secrets                       | `TwoFactorRepository`                                |
| 1m       | Remove expired passkey sessions                       | `PasskeyRepository`                                  |
| 1m       | Cleanup trashed collections                           | `TrashController`                                    |
| 1m       | Send queued push notifications                        | `PushController`                                     |
| 1m       | Health check ping                                     | `HealthCheckHandler`                                 |
| 8m       | Cleanup permanently deleted files                     | `FileController`                                     |
| 17m      | Drop file metadata from trash                         | `TrashController`                                    |
| 30m      | Cleanup expired pastes                                | `PasteRepository`                                    |
| 45m      | Delete unclaimed Cast codes + data cleanup            | `CastDb` + `DataCleanupCtrl`                         |
| 60m      | Send recovery reminders + cleanup expired locks       | `EmergencyController` + `TaskLockRepository`         |
| 63s      | Process storage bonus upgrade/downgrade               | `StorageBonusController`                             |
| 67s      | Process empty trash requests                          | `TrashController`                                    |
| 90s      | Remove Wasabi compliance holds                        | `ObjectController`                                   |
| 101s     | Cleanup deleted embeddings                            | `EmbeddingController`                                |
| 101s     | Delete aged trashed files                             | `TrashController`                                    |
| 24h      | Remove old auth tokens + cast sessions + link history | `UserAuthRepository` + `CastDb`                      |
| 24h      | Send storage limit exceeded emails                    | `EmailNotificationController`                        |
| 24h      | Send storage warning emails                           | `EmailNotificationController`                        |
| 24h      | Send welcome emails                                   | `EmailNotificationController`                        |
| 24h      | Nudge for family plan + cleanup fake SRP sessions     | `EmailNotificationController` + `UserAuthRepository` |
| 24h      | Process inactive users                                | `InactiveUserOrchestrator`                           |
| 24h      | Clear expired push tokens                             | `PushController`                                     |

### Queue system (DB-backed)

- Table: `queue(queue_id, queue_name, item, is_deleted, created_at)`
- Queue names: `deleteObject` (45-day delay), `dropFileEncMetata`, `deleteEmbedding`, `trashCollectionV3`, `trashEmpty`, `trashEmptyLocker`, `removeComplianceHold`
- Deprecated queues (kept for backward compat): `trashCollection`, `outdatedObject`
- Repo: `pkg/repo/queue.go`
- Processing: Cron jobs fetch batches of 30,000 items

### Background workers (goroutines)

Started in `setupAndStartBackgroundJobs()` (`cmd/museum/main.go:1130`):

- **File Replication V3** — replicate objects to secondary DCs (requires `replication.enabled: true`)
- **File Data Replication** — replicate file metadata (requires `replication.enabled: true`)
- **Contact Attachment Replication** — replicate contact attachments to secondary DCs (requires `replication.enabled: true`)
- **File Data Deletion** — delete file data for removed files
- **Contact Data Deletion** — delete attachment data for removed contacts
- **Unreported Objects Cleanup** — remove unreported S3 objects
- **Orphan Object Cleanup** — remove stranded S3 objects

---

## External Integrations

| Service                          | Package                                          | Config Key                             |
| -------------------------------- | ------------------------------------------------ | -------------------------------------- |
| Stripe (payments)                | `pkg/controller/stripe.go`, `pkg/utils/billing/` | `stripe.*`                             |
| Apple IAP                        | `pkg/controller/appstore.go`                     | `apple.shared-secret`                  |
| Google Play                      | `pkg/controller/playstore.go`                    | (via service account)                  |
| Firebase (push)                  | `pkg/controller/push.go`                         | `credentials/fcm-service-account.json` |
| S3 (B2, Wasabi, Scaleway, MinIO) | `pkg/utils/s3config/`                            | `s3.*`                                 |
| SMTP email                       | `pkg/utils/email/email.go`                       | `smtp.*`                               |
| Transmail (Zoho)                 | `pkg/utils/email/email.go`                       | `transmail.*`                          |
| Discord (alerts)                 | `pkg/controller/discord/`                        | `discord.*`                            |
| Wasabi compliance                | `pkg/external/wasabi/`                           | (via S3 config)                        |
| Zoho Zeptomail                   | `pkg/external/zoho/`                             | `transmail.*`                          |
| Listmonk (email marketing)       | `pkg/external/listmonk/`                         | `listmonk.*`                           |

`pkg/controller/mailing_lists.go` orchestrates list subscription/unsubscription across the Listmonk and Zoho clients — call into it rather than the external clients directly.

---

## Error Handling

**Error definitions:** `ente/errors.go`
**HTTP mapping:** `pkg/utils/handler/handler.go`

| Error                                     | HTTP Status               |
| ----------------------------------------- | ------------------------- |
| `ErrNotFound`, `sql.ErrNoRows`                                                | 404                       |
| `ErrBadRequest`, `ErrCannotDowngrade`, `ErrCannotSwitchPaymentProvider`       | 400                       |
| `ErrPermissionDenied`                                                         | 403                       |
| `ErrIncorrectOTT`, `ErrIncorrectTOTP`, `ErrInvalidPassword`, `ErrAuthenticationRequired` | 401            |
| `ErrNoActiveSubscription`, `ErrSharingDisabledForFreeAccounts`                | 402                       |
| `ErrStorageLimitExceeded`                                                     | 426                       |
| `ErrFileTooLarge`, `ErrBatchSizeTooLarge`                                     | 413                       |
| `ErrVersionMismatch`, `ErrCanNotInviteUserWithPaidPlan`                       | 409                       |
| `ErrCanNotInviteUserAlreadyInFamily`                                          | 406                       |
| `ErrFamilySizeLimitReached`                                                   | 412                       |
| `ErrExpiredOTT`, `ErrUserDeleted`                                             | 410                       |
| `ErrTooManyBadRequest`                                                        | 429                       |
| `ErrNotImplemented`                                                           | 501                       |
| `ente.ApiError` (custom)                                                      | `ApiError.HttpStatusCode` |
| Validation errors                                                             | 400                       |
| Unknown errors                                                                | 500                       |

**Handler pattern:**

```go
func (h *Handler) DoSomething(c *gin.Context) {
    var request ente.SomeRequest
    if err := c.ShouldBindJSON(&request); err != nil {
        handler.Error(c, stacktrace.Propagate(err, ""))
        return
    }
    result, err := h.Controller.DoSomething(c, request)
    if err != nil {
        handler.Error(c, stacktrace.Propagate(err, ""))
        return
    }
    c.JSON(http.StatusOK, result)
}
```

---

## Development

### Run with Docker (recommended)

```bash
docker compose up --build          # Museum + Postgres + MinIO on :8080
curl http://localhost:8080/ping     # Verify
```

### Run without Docker

```bash
go build -o bin/museum cmd/museum/main.go
ENVIRONMENT=local ./bin/museum
```

### Live reload

```bash
# Uses .air.toml config
air
```

### Connect to dev DB

```bash
docker compose exec postgres env PGPASSWORD=pgpass psql -U pguser -d ente_db
```

### Connect to MinIO

```bash
AWS_ACCESS_KEY_ID=changeme AWS_SECRET_ACCESS_KEY=changeme1234 \
    aws s3 --endpoint-url http://localhost:3200 ls s3://b2-eu-cen
```

### Run tests

```bash
go test -v ./pkg/...
go clean -testcache && ENV="test" go test -v ./pkg/...
./scripts/test-in-docker.sh         # Full Docker-based test run
```

### Generate encryption keys (self-hosting)

```bash
go run tools/gen-random-keys/main.go
```

### Point clients to local server

- **Web:** `NEXT_PUBLIC_ENTE_ENDPOINT=http://localhost:8080 yarn dev`
- **Mobile:** `flutter run --dart-define=endpoint=http://localhost:8080`
- **Mobile (alt):** Tap onboarding screen 7 times → developer settings → enter endpoint

---

## Monitoring

- **Prometheus metrics:** Exposed on `:2112/metrics`
- **Tracked metrics:** `museum_method_latency` (per endpoint), `museum_latency` (per status/method)
- **Logging:** Logrus — text to stdout (local), JSON to file with rotation (production)
- **Discord:** Startup/shutdown notifications, rate limit breach alerts

---

## Critical Gotchas

1. **`main.go` is massive** (~1,406 lines) — all DI wiring, route registration, and cron setup live here. Search by handler/controller name to find routes.
2. **No ORM** — all SQL is hand-written in repo files. Check `migrations/` for schema.
3. **Emails are encrypted at rest** — stored via `pkg/utils/crypto/`, looked up by BLAKE2b hash. The `key.encryption` and `key.hash` config values are critical.
4. **Three S3 buckets required** — hardcoded names `b2-eu-cen`, `wasabi-eu-central-2-v3`, `scw-eu-fr-v3`. Any S3-compatible provider works; names are arbitrary.
5. **Wasabi compliance holds** — 21-day retention lock on objects. Cron job removes holds after expiry.
6. **API versioning is path-based** — e.g., `/files/download/:fileID` vs `/files/download/v2/:fileID`. Same handler may serve both.
7. **Admin is config-based** — user IDs in `internal.admins` config, or first registered user if unconfigured.
8. **Queue is DB-backed** — not a message broker. The `queue` table with soft deletes and cron-based polling.
9. **Migrations auto-run on startup** — no separate migration step needed.
10. **Rate limiting is multi-level** — global (1000 req/s), per-API (configurable), per-user (authenticated endpoints).
11. **`museum.yaml`** is gitignored — use it for local overrides without touching tracked config files.
12. **Multiple Stripe accounts** — US and India regions have separate API keys and webhook secrets.
13. **Passkey RPID migration in progress** — `webauthn.rpid` (currently `ente.com`) and `webauthn.legacy-rpid` (`ente.io`) coexist. New credentials use the primary RPID; pre-migration credentials carry a per-record RPID in `passkey_rp_ids`. Don't assume all passkeys share one RPID when validating WebAuthn assertions.
14. **Public links require a browser device token** — Public collection / file / memory endpoints expect a per-device JWT (issued by `pkg/controller/public/link_device_token.go`) in addition to `X-Auth-Access-Token`. Free users are capped at 5 devices per link via the `device_limit` column on the public-token tables. When exercising public-link endpoints locally, mint a device token first.
