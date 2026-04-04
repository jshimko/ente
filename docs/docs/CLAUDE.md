# CLAUDE.md

Reference guide for AI agents working with Ente documentation. Focus areas: self-hosting and Kubernetes deployment.

**Documented:** 2026-03-31
**Commit:** c5bb7228494c8613deb41eeb0b7cb729bb12732f

## Overview

VitePress documentation site for Ente products. Published at [ente.com/help](https://ente.com/help).

**Structure:** ~190 markdown files across 7 product areas:

- `self-hosting/` - Server deployment (26 files) **[Primary focus]**
- `photos/` - Ente Photos app (114 files)
- `locker/` - Ente Locker secure storage (31 files)
- `auth/` - Ente Auth 2FA app (13 files)
- `ensu/` - Ensu local AI chat (2 files)
- `cli/` - CLI tool (1 file)
- `de/` - German translations (1 file)
- `.vitepress/` - Site configuration

---

## Quick Navigation

| To find...                      | Look in...                                      |
| ------------------------------- | ----------------------------------------------- |
| **Kubernetes deployment**       | `self-hosting/guides/photos-k8s-helm.md`        |
| **Quickstart script**           | `self-hosting/installation/quickstart.md`       |
| **Quick Docker preview**        | `self-hosting/index.md`                         |
| **Configuration reference**     | `self-hosting/installation/config.md`           |
| **Environment variables**       | `self-hosting/installation/env-var.md`          |
| **S3/Object storage setup**     | `self-hosting/administration/object-storage.md` |
| **Reverse proxy (Caddy/NGINX)** | `self-hosting/administration/reverse-proxy.md`  |
| **Backup strategy**             | `self-hosting/administration/backup.md`         |
| **User management**             | `self-hosting/administration/users.md`          |
| **Upload troubleshooting**      | `self-hosting/troubleshooting/uploads.md`       |
| **Docker troubleshooting**      | `self-hosting/troubleshooting/docker.md`        |
| **Storage cleanup timing**      | `self-hosting/troubleshooting/misc.md`          |
| **Lima VM development**         | `self-hosting/development/lima.md`              |
| **Photos app docs**             | `photos/`                                       |
| **Locker app docs**             | `locker/`                                       |
| **Auth app docs**               | `auth/`                                         |
| **Ensu docs**                   | `ensu/`                                         |
| **Ensu FAQ**                    | `ensu/faq/`                                     |
| **Style guide**                 | `photos/STYLE_GUIDE.md`                         |

---

## Architecture Overview

### Core Components

| Component          | Technology          | Default Port | Role                                 |
| ------------------ | ------------------- | ------------ | ------------------------------------ |
| **Museum**         | Go binary           | 8080         | API server (stateless)               |
| **PostgreSQL**     | PostgreSQL 14+      | 5432         | Metadata, encryption keys, user data |
| **Object Storage** | S3-compatible       | varies       | Encrypted photos/videos/files        |
| **Web Apps**       | Nginx-served static | 3000-3008    | 8 web applications                   |

Museum is stateless: all persistent state lives in PostgreSQL and S3. Museum pods can be horizontally scaled and freely restarted.

### Web App Port Map

| Port | Application                |
| ---- | -------------------------- |
| 3000 | Ente Photos                |
| 3001 | Ente Accounts              |
| 3002 | Ente Albums                |
| 3003 | Ente Auth                  |
| 3004 | Ente Cast                  |
| 3005 | Ente Public Locker (Share) |
| 3006 | Ente Embed                 |
| 3008 | Ente Paste                 |
| 3200 | MinIO S3 (console on 3201) |

### Data Decryption Model

Three pieces are needed to access data:

1. Encrypted file data (from S3)
2. Encrypted file/collection encryption keys (from PostgreSQL)
3. Master key (derived from user's password)

**Database backup is therefore essential** - without it, S3 data is permanently inaccessible.

---

## Self-Hosting Reference

### Installation Methods

| Method                | File                         | Use Case                               |
| --------------------- | ---------------------------- | -------------------------------------- |
| **Quickstart script** | `installation/quickstart.md` | One-command Docker setup (recommended) |
| **Docker Compose**    | `installation/compose.md`    | Build from source                      |
| **Kubernetes/Helm**   | `guides/photos-k8s-helm.md`  | Production K8s cluster                 |
| **Manual**            | `installation/manual.md`     | No Docker, build from source           |
| **Systemd**           | `guides/systemd.md`          | Linux service management               |
| **Tailscale**         | `guides/tailscale.md`        | Behind CGNAT / private network         |
| **Windows**           | `guides/windows.md`          | Windows Docker Desktop                 |
| **Lima VM**           | `development/lima.md`        | macOS local development                |

### Requirements

- **Hardware:** 1GB RAM, 1 CPU minimum
- **Software:** Docker Compose 2.30+ (`docker compose`, not `docker-compose`)
- **Storage:** Unix-compatible filesystem (ZFS, EXT4, BTRFS)
- **OS:** Linux recommended (Ubuntu/Debian); non-Linux has poor Docker support

---

## Kubernetes Deployment (Detailed)

**Primary guide:** `self-hosting/guides/photos-k8s-helm.md`

### Prerequisites

- Kubernetes 1.23+
- Helm 3.8+
- External PostgreSQL 14+ (CloudNativePG recommended)
- S3-compatible storage
- Ingress controller (nginx/traefik)
- cert-manager (recommended for TLS)

### Helm Chart Resources

- **Package:** <https://artifacthub.io/packages/helm/l4g/ente-photos>
- **Source:** <https://github.com/l4gdev/helm-charts/tree/main/charts/ente-photos>

**Note:** Community-maintained, not official Ente project. Verify compatibility with your Ente version.

### Deployment Decision Matrix

| Scenario            | PostgreSQL                 | S3 Storage                 | Ingress                                     |
| ------------------- | -------------------------- | -------------------------- | ------------------------------------------- |
| Single-user homelab | CloudNativePG in-cluster   | Garage in-cluster or MinIO | Traefik/nginx                               |
| Small team (<10)    | CloudNativePG in-cluster   | Managed S3 (Wasabi/B2)     | nginx-ingress                               |
| Production org      | Managed PG (RDS/Cloud SQL) | Managed S3 (AWS/GCS)       | nginx-ingress + cert-manager + external-dns |

### Installation Commands

```sh
# Add repository
helm repo add l4g https://l4gdev.github.io/helm-charts
helm repo update

# Verify availability
helm search repo l4g/ente-photos

# Install
kubectl create namespace ente-photos
helm install ente-photos l4g/ente-photos \
  --namespace ente-photos \
  --values values.yaml
```

### Complete Helm values.yaml Reference

```yaml
# --- PostgreSQL (required) ---
externalDatabase:
    host: "postgres-host"
    port: 5432
    database: "ente_db"
    user: "ente"
    password: "password" # Or use existingSecret below
    existingSecret:
        enabled: false
        secretName: "secret-name"
        passwordKey: "password"

# --- Credentials ---
credentials:
    existingSecret: "" # K8s secret with credentials.yaml key

    s3:
        primary: # Required: object storage
            key: "access-key"
            secret: "secret-key"
            endpoint: "https://s3.region.amazonaws.com"
            region: "region"
            bucket: "bucket-name"
            areLocalBuckets: false # true for MinIO/Garage

    encryption: # MUST set for production
        key: "" # openssl rand 32 | base64
        hash: "" # openssl rand 64 | base64

    jwt: # MUST set for production
        secret: "" # openssl rand 32 | base64

    smtp: # Optional: email delivery
        enabled: false
        host: "smtp.example.com"
        port: 587
        username: ""
        password: ""
        from: "noreply@example.com"

# --- Museum (API server) ---
museum:
    config: # Maps to museum.yaml sections
        s3:
            areLocalBuckets: false
            usePathStyleUrls: false # true for MinIO/Garage
        apps:
            publicAlbums: "https://albums.example.com"
            accounts: "https://accounts.example.com"
            cast: "https://cast.example.com"
            embedAlbums: "https://embed.example.com"
            publicLocker: "https://share.example.com"
            publicPaste: "https://paste.example.com"
        internal:
            admins: [] # User IDs for admin access
            disable-registration: false

    ingress:
        enabled: true
        className: nginx
        annotations:
            cert-manager.io/cluster-issuer: letsencrypt-prod
            nginx.ingress.kubernetes.io/proxy-body-size: "50g"
        hosts:
            - host: api.photos.example.com
              paths:
                  - path: /
                    pathType: Prefix
        tls:
            - secretName: ente-api-tls
              hosts:
                  - api.photos.example.com

    resources:
        requests:
            cpu: 200m
            memory: 256Mi
        limits:
            cpu: 1000m
            memory: 1Gi

# --- Web Apps ---
# Each web app has: enabled, ingress, resources
web:
    photos:
        enabled: true
        ingress:
            enabled: true
            className: nginx
            annotations:
                cert-manager.io/cluster-issuer: letsencrypt-prod
            hosts:
                - host: photos.example.com
                  paths:
                      - path: /
                        pathType: Prefix
            tls:
                - secretName: ente-photos-tls
                  hosts:
                      - photos.example.com
        resources:
            requests: { cpu: 50m, memory: 64Mi }
            limits: { cpu: 200m, memory: 256Mi }

    auth:
        enabled: true
        ingress: { ... } # Same structure as photos
    accounts:
        enabled: true
        ingress: { ... }
    share: # Public Locker
        enabled: true
        ingress: { ... }
```

### CloudNativePG Integration

Recommended PostgreSQL operator for Kubernetes. Reference the generated secret:

```yaml
# CloudNativePG Cluster CRD
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
    name: ente-db
    namespace: database
spec:
    instances: 3
    postgresql:
        parameters:
            max_connections: "200"
    storage:
        size: 10Gi
    bootstrap:
        initdb:
            database: ente_db
            owner: ente
```

```yaml
# Helm values referencing CloudNativePG secret
externalDatabase:
    host: "ente-db-rw.database.svc.cluster.local"
    port: 5432
    database: "ente_db"
    user: "ente"
    existingSecret:
        enabled: true
        secretName: "ente-db-app"
        passwordKey: "password"
```

### Self-Hosted S3 (MinIO/Garage)

```yaml
museum:
    config:
        s3:
            areLocalBuckets: true
            usePathStyleUrls: true

credentials:
    s3:
        primary:
            key: "access-key"
            secret: "secret-key"
            endpoint: "https://s3.example.com"
            region: "us-east-1"
            bucket: "ente-photos"
            areLocalBuckets: true
```

MinIO has dropped open-source support. Consider [Garage](https://garagehq.deuxfleurs.fr/) for self-hosted S3.

### Encryption Keys (Production Required)

```sh
# Generate keys
openssl rand 32 | base64  # encryption key
openssl rand 64 | base64  # hash key
openssl rand 32 | base64  # JWT secret
```

```yaml
credentials:
    encryption:
        key: "generated-encryption-key"
        hash: "generated-hash-key"
    jwt:
        secret: "generated-jwt-secret"
```

**Warning:** If not provided, keys regenerate on each Helm upgrade, making existing data inaccessible.

### Using Existing Kubernetes Secrets

```yaml
credentials:
    existingSecret: "my-ente-credentials"

externalDatabase:
    host: "your-postgres-host"
    existingSecret:
        enabled: true
        secretName: "my-postgres-credentials"
        passwordKey: "password"
```

The credentials secret should contain a `credentials.yaml` key with the complete credentials configuration.

### Disabling Web Frontends

If you only need the API server (e.g., mobile apps only):

```yaml
web:
    photos: { enabled: false }
    auth: { enabled: false }
    accounts: { enabled: false }
    share: { enabled: false }
```

### Kubernetes Operational Runbook

#### Day-1 Operations

1. **Verify deployment:**

    ```sh
    kubectl get pods -n ente-photos -w
    kubectl exec -it deploy/ente-photos-museum -n ente-photos -- \
      wget -qO- http://localhost:8080/ping
    ```

2. **Create first user:** Open web app (e.g., `https://photos.example.com`), select "Don't have an account?"

3. **Get verification code** (if no SMTP):

    ```sh
    kubectl logs deploy/ente-photos-museum -n ente-photos | grep -i "ott"
    ```

4. **Set admin user:**

    ```sh
    # Get user ID from database
    kubectl exec -it <postgres-pod> -- psql -U ente -d ente_db \
      -c "SELECT user_id, email FROM users;"
    ```

    Add to values.yaml under `museum.config.internal.admins`, then `helm upgrade`.

5. **Disable registration:**

    ```yaml
    museum:
        config:
            internal:
                disable-registration: true
    ```

#### Day-2 Operations

- **Upgrade:** `helm repo update && helm upgrade ente-photos l4g/ente-photos -n ente-photos --values values.yaml`
- **Uninstall:** `helm uninstall ente-photos -n ente-photos` (data persists in DB/S3)
- **Scale Museum:** Museum is stateless; increase replicas freely
- **Certificate renewal:** cert-manager handles automatically
- **Backup:** pg_dumpall for PostgreSQL, S3 versioning for object storage

#### Key kubectl Commands

```sh
# Pod status
kubectl get pods -n ente-photos -w

# Museum health
kubectl exec -it deploy/ente-photos-museum -n ente-photos -- wget -qO- http://localhost:8080/ping

# Museum logs
kubectl logs deploy/ente-photos-museum -n ente-photos

# Get OTT codes
kubectl logs deploy/ente-photos-museum -n ente-photos | grep -i "ott"

# Debug database
kubectl logs deploy/ente-photos-museum -n ente-photos | grep -i "database\|postgres"

# Debug S3
kubectl logs deploy/ente-photos-museum -n ente-photos | grep -i "s3\|bucket"

# Pod events
kubectl describe pod -l app.kubernetes.io/name=ente-photos -n ente-photos

# Ingress status
kubectl get ingress -n ente-photos

# TLS certificates
kubectl get certificate -n ente-photos
```

---

## Configuration Reference

**File:** `self-hosting/installation/config.md`

### museum.yaml Structure

Configuration loaded by Museum server. Environment variables with `ENTE_` prefix override YAML values.

Example: `s3.b2-eu-cen.endpoint` becomes `ENTE_S3_B2_EU_CEN_ENDPOINT`

Web apps use cluster environment variables `ENTE_API_ORIGIN`, `ENTE_ALBUMS_ORIGIN`, and `ENTE_PHOTOS_ORIGIN` to discover Museum and other services. See `self-hosting/installation/env-var.md` for the full port mapping and precedence order.

**Precedence:** env vars (`ENTE_*`) > museum.yaml > credentials file > base config (`configurations/{ENVIRONMENT}.yaml`)

### Key Sections

| Section         | Purpose                                                           |
| --------------- | ----------------------------------------------------------------- |
| `db.*`          | PostgreSQL connection (host, port, name, user, password, sslmode) |
| `s3.*`          | Object storage buckets                                            |
| `apps.*`        | Web app endpoints                                                 |
| `key.*`         | Encryption keys                                                   |
| `jwt.*`         | JWT signing secret                                                |
| `smtp.*`        | Email configuration                                               |
| `listmonk.*`    | Listmonk mailing list integration                                 |
| `webauthn.*`    | Passkey support (rpid, rporigins)                                 |
| `internal.*`    | Admin settings, registration control, hardcoded OTTs              |
| `replication.*` | Multi-bucket replication                                          |
| `jobs.*`        | Background cron jobs and cleanup                                  |

### S3 Bucket Names (Hardcoded)

- `b2-eu-cen` - Primary hot storage (default)
- `wasabi-eu-central-2-v3` - Secondary hot storage (default)
- `scw-eu-fr-v3` - Cold storage
- `wasabi-eu-central-2-derived` - Derived storage (embeddings, previews)
- `b5` - Additional bucket
- `b6` - Additional bucket

Names are hardcoded but have no relation to Backblaze/Wasabi/Scaleway. Any S3 provider works. If replication is disabled (the default), only the primary hot storage bucket needs valid credentials.

### Global S3 Settings

| Key                        | Purpose                                                   | Default                  |
| -------------------------- | --------------------------------------------------------- | ------------------------ |
| `s3.are_local_buckets`     | Disable SSL, use path-style URLs, skip GLACIER class      | `false`                  |
| `s3.use_path_style_urls`   | Force path-style S3 URLs (required for MinIO)             | `false`                  |
| `s3.hot_storage.primary`   | Override primary hot storage bucket ID                    | `b2-eu-cen`              |
| `s3.hot_storage.secondary` | Override secondary hot storage bucket ID                  | `wasabi-eu-central-2-v3` |
| `s3.derived-storage`       | Override derived storage bucket ID (embeddings, previews) | primary bucket           |

Per-bucket overrides are available for `use_path_style_urls`, `are_local_buckets`, and `disable_ssl` using the pattern `s3.{id}.key_name`.

### App Endpoints

```yaml
apps:
    public-albums: https://albums.example.com
    public-locker: https://share.example.com
    public-paste: https://paste.example.com
    cast: https://cast.example.com
    embed-albums: https://embed.example.com
    accounts: https://accounts.example.com
    family: https://family.example.com
    public-memories: https://memories.example.com
    custom-domain:
        cname: my.ente.io
```

---

## Common Tasks

### First User Setup

1. Open web app (e.g., `https://photos.example.com`)
2. Select "Don't have an account?"
3. Register with email
4. Get verification code from logs (if no SMTP):
    - **Docker:** `docker compose logs | grep -i "ott"`
    - **Kubernetes:** `kubectl logs deploy/ente-photos-museum -n ente-photos | grep -i "ott"`

First registered user is automatically admin.

### Whitelist Admin

```sh
# Get user ID from database
# Docker:
docker exec -it <postgres-container> psql -U pguser -d ente_db -c "SELECT user_id, email FROM users;"
# Kubernetes:
kubectl exec -it <postgres-pod> -- psql -U ente -d ente_db -c "SELECT user_id, email FROM users;"
```

Add to museum.yaml or Helm values:

```yaml
internal:
    admins:
        - <user_id>
```

**Note:** For env-var-only setups (Kubernetes, GitOps), use `internal.admin` (`ENTE_INTERNAL_ADMIN`) with a single user ID instead of `internal.admins`, which has Viper limitations with array env vars.

### Disable Registration

```yaml
internal:
    disable-registration: true
```

### Hardcoded OTTs (Testing)

```yaml
internal:
    hardcoded-ott:
        emails:
            - "user@example.com,123456"
        local-domain-suffix: "@example.org"
        local-domain-value: 012345
```

### Increase Storage and Account Validity

Use the Ente CLI. See `self-hosting/administration/cli.md`.

### CORS Configuration

Create `cors.json`:

```json
{
    "CORSRules": [
        {
            "AllowedOrigins": ["*"],
            "AllowedHeaders": ["*"],
            "AllowedMethods": ["GET", "HEAD", "POST", "PUT", "DELETE"],
            "MaxAgeSeconds": 3000,
            "ExposeHeaders": ["Etag"]
        }
    ]
}
```

Apply:

```sh
# AWS CLI
aws s3api put-bucket-cors --bucket BUCKET --cors-configuration file://cors.json

# MinIO
mc alias set storage http://endpoint user password
mc admin config set storage api cors_allow_origin="*"
```

**Note:** Newer builds include `Content-MD5` and `UPLOAD-URL` headers. If your provider requires explicit AllowedHeaders (not `*`), include these.

### Configure Mobile/Desktop Apps

Tap onboarding screen 7 times to access developer settings. Enter server endpoint.

### Expedite Storage Cleanup

Deleted files take up to 75 days (30-day trash + 45-day deletion queue). To speed up:

1. Empty trash from the app (skips 30-day wait)
2. Expedite deletion queue via SQL:

    ```sql
    UPDATE queue
    SET created_at = now_utc_micro_seconds() - (46 * 24 * 60 * 60 * 1000000)
    WHERE queue_name = 'deleteObject';
    ```

---

## Troubleshooting Quick-Reference

### Symptom -> Cause -> Fix

| Symptom                              | Likely Cause                    | Fix                                                                  | Ref                          |
| ------------------------------------ | ------------------------------- | -------------------------------------------------------------------- | ---------------------------- |
| 403 on upload                        | CORS misconfigured              | Set AllowedOrigins, add `Content-MD5`/`UPLOAD-URL` to AllowedHeaders | `troubleshooting/uploads.md` |
| 403 on upload                        | Wrong S3 credentials            | Verify credentials in museum.yaml match provider                     | `troubleshooting/uploads.md` |
| "Mismatch in file size"              | Interrupted re-upload           | Normal; retry upload                                                 | `troubleshooting/uploads.md` |
| Museum panic: "password auth failed" | Stale Docker volume             | Delete volumes or rename my-ente dir                                 | `troubleshooting/docker.md`  |
| "post_start not allowed"             | Docker Compose < 2.30           | Upgrade Docker Compose or use minio-provision service                | `troubleshooting/docker.md`  |
| "start_interval not allowed"         | Old Docker Compose              | Upgrade Docker Compose                                               | `troubleshooting/docker.md`  |
| MinIO "Waiting for minio..." loop    | Deprecated mc config            | Change `mc config host add` to `mc alias set`                        | `troubleshooting/docker.md`  |
| Albums/video not working             | CSP headers incomplete          | Check browser console; match \_headers file template                 | `troubleshooting/misc.md`    |
| Storage not freed after delete       | 30-day trash + 45-day queue     | Empty trash; optionally expedite via SQL                             | `troubleshooting/misc.md`    |
| Pod CrashLoopBackOff                 | DB connection or missing config | `kubectl describe pod`; check logs for error                         | `guides/photos-k8s-helm.md`  |
| Encryption keys regenerated          | Keys not set in values.yaml     | Always set `credentials.encryption` and `jwt`                        | `guides/photos-k8s-helm.md`  |

### K8s-Specific Diagnostics

1. **Pod not starting:** `kubectl describe pod -l app.kubernetes.io/name=ente-photos -n ente-photos`
2. **Database errors:** `kubectl logs deploy/ente-photos-museum -n ente-photos | grep -i "database\|postgres"`
3. **S3 errors:** `kubectl logs deploy/ente-photos-museum -n ente-photos | grep -i "s3\|bucket"`
4. **Ingress not routing:** `kubectl get ingress -n ente-photos` - check annotations and TLS secrets
5. **Certificate issues:** `kubectl get certificate -n ente-photos && kubectl describe certificate -n ente-photos`

---

## Critical Gotchas

1. **Database backup is essential** - contains encryption keys; without them S3 data is permanently inaccessible
2. **HTTPS required** for Museum in production (rejects HTTP traffic)
3. **CORS must be configured** for browser-based uploads (include `Content-MD5` and `UPLOAD-URL` in AllowedHeaders)
4. **MinIO is deprecated** - use Garage or managed S3 instead; MinIO dropped open-source support
5. **Helm chart is community-maintained** (`l4g/ente-photos`) - not official Ente project; verify compatibility
6. **Encryption keys must persist** - if not explicitly set in Helm values, regenerated on upgrade, breaking existing data
7. **Docker Compose 2.30+** required for post_start lifecycle hooks
8. **Sidebar is manually maintained** - new docs pages must be added to `.vitepress/sidebar.ts`
9. **S3 bucket names are hardcoded** - `b2-eu-cen`, `wasabi-eu-central-2-v3`, `scw-eu-fr-v3` (names only; any provider works)
10. **Storage cleanup is delayed** - up to 75 days (30-day trash + 45-day deletion queue)

---

## Documentation Site

### Build System

- **Framework:** VitePress 1.6.4
- **Package manager:** Yarn 1.22.22
- **Published at:** ente.com/help (base path `/help/`)
- **Deployed via:** Cloudflare Pages (GitHub Actions on push to main)

```bash
yarn install       # Install dependencies
yarn dev           # Local dev server (localhost:5173)
yarn build         # Production build → docs/.vitepress/dist
yarn preview       # Preview built site
yarn pretty        # Format with Prettier
yarn pretty:check  # Check formatting
```

### Key Config Features

- Clean URLs (no .html extensions)
- Auto sitemap with deduplication
- Local search with detailed view
- FAQ schema markup (auto-generated for `/faq/` pages)
- Breadcrumb schema markup
- Canonical URLs per page
- Open Graph and Twitter Card meta tags
- External link icons
- GitHub edit links

### Style Guide Summary

Full guide: `photos/STYLE_GUIDE.md`

- Imperative voice: "Open Settings" not "You can open Settings"
- "Open" for navigation (NOT "Go to" or "Navigate to")
- **Tap** for mobile, **Click** for desktop
- Settings paths: `` `Settings > Backup > Folders` `` (code-formatted with `>`)
- FAQ anchors: `### Question? {#unique-anchor-id}` (must be unique across all FAQ files)
- "Learn more" (NOT "See more", "For more details", "Read more")
- Platform headers: `**On mobile:**`, `**On desktop:**`, `**On web:**`

Check for duplicate anchors:

```bash
grep -rh "{#[a-z0-9-]*}" docs/photos/faq/*.md | sed 's/.*{#\([^}]*\)}.*/\1/' | sort | uniq -d
```

---

## External Resources

- **Helm Chart:** <https://artifacthub.io/packages/helm/l4g/ente-photos>
- **Chart Source:** <https://github.com/l4gdev/helm-charts/tree/main/charts/ente-photos>
- **CloudNativePG:** <https://cloudnative-pg.io/>
- **Garage (S3):** <https://garagehq.deuxfleurs.fr/>
- **GitHub Discussions:** <https://github.com/ente-io/ente/discussions>
- **Discord:** <https://ente.com/discord>

---

## File Index

### Self-Hosting (Priority)

| Path                                              | Content                            |
| ------------------------------------------------- | ---------------------------------- |
| `self-hosting/index.md`                           | Overview, quickstart command       |
| `self-hosting/guides/photos-k8s-helm.md`          | Kubernetes Helm deployment         |
| `self-hosting/guides/systemd.md`                  | Systemd service setup              |
| `self-hosting/guides/tailscale.md`                | Tailscale VPN deployment           |
| `self-hosting/guides/windows.md`                  | Windows Docker setup               |
| `self-hosting/guides/index.md`                    | Guides overview and directory      |
| `self-hosting/installation/quickstart.md`         | Quickstart script details          |
| `self-hosting/installation/config.md`             | museum.yaml reference              |
| `self-hosting/installation/compose.md`            | Docker Compose from source         |
| `self-hosting/installation/requirements.md`       | Hardware/software requirements     |
| `self-hosting/installation/env-var.md`            | Environment variables and port map |
| `self-hosting/installation/manual.md`             | Non-Docker setup                   |
| `self-hosting/installation/upgrade.md`            | Upgrade procedures                 |
| `self-hosting/installation/post-install/index.md` | Post-install steps                 |
| `self-hosting/administration/backup.md`           | Backup strategy                    |
| `self-hosting/administration/object-storage.md`   | S3, CORS, replication              |
| `self-hosting/administration/users.md`            | User/admin management              |
| `self-hosting/administration/reverse-proxy.md`    | Caddy/NGINX/Traefik setup          |
| `self-hosting/administration/cli.md`              | CLI configuration                  |
| `self-hosting/development/mobile-build.md`        | Building mobile apps               |
| `self-hosting/development/lima.md`                | Lima VM for macOS                  |
| `self-hosting/troubleshooting/uploads.md`         | 403, CORS, file size errors        |
| `self-hosting/troubleshooting/docker.md`          | Docker Compose issues              |
| `self-hosting/troubleshooting/misc.md`            | CSP headers, storage cleanup       |
| `self-hosting/troubleshooting/cli.md`             | CLI keyring issues                 |

### Photos Documentation

| Path                      | Content                            |
| ------------------------- | ---------------------------------- |
| `photos/index.md`         | Photos overview                    |
| `photos/STYLE_GUIDE.md`   | Documentation style standards      |
| `photos/getting-started/` | Getting started guides (6 files)   |
| `photos/features/`        | Feature documentation (69 files)   |
| `photos/faq/`             | FAQ organized by topic (23 files)  |
| `photos/migration/`       | Migration from Google/Apple/Amazon |
| `photos/troubleshooting/` | Upload and desktop issues          |

### Locker Documentation

| Path                      | Content                         |
| ------------------------- | ------------------------------- |
| `locker/index.md`         | Locker overview                 |
| `locker/getting-started/` | Getting started (5 files)       |
| `locker/features/`        | Features by category (17 files) |
| `locker/faq/`             | FAQ by topic (8 files)          |

### Auth Documentation

| Path              | Content                        |
| ----------------- | ------------------------------ |
| `auth/index.md`   | Auth overview                  |
| `auth/features/`  | Feature documentation          |
| `auth/migration/` | Import from Authy, Steam, etc. |
| `auth/faq/`       | FAQ and privacy info           |

### Ensu Documentation

| Path                | Content                           |
| ------------------- | --------------------------------- |
| `ensu/index.md`     | Ensu overview (local AI chat app) |
| `ensu/faq/index.md` | Ensu FAQ                          |

### CLI Documentation

| Path           | Content                |
| -------------- | ---------------------- |
| `cli/index.md` | CLI usage and commands |

### Site Configuration

| Path                          | Content                                     |
| ----------------------------- | ------------------------------------------- |
| `.vitepress/config.ts`        | Main VitePress configuration                |
| `.vitepress/sidebar.ts`       | Navigation sidebar (manually maintained)    |
| `.vitepress/theme/index.js`   | Theme entry point                           |
| `.vitepress/theme/custom.css` | Brand color overrides (Ente green: #1db954) |
