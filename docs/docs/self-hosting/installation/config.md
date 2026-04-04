---
title: Configuration - Self-hosting
description:
    "Information about all the configuration variables needed to run Ente with
    museum.yaml"
---

# Configuration

Museum is designed to be configured either via environment variables or via
YAML. We recommend using YAML for maintaining your configuration as it can be
backed up easily, helping in restoration.

## Configuration File

Museum's configuration file (`museum.yaml`) is responsible for making database
configuration, bucket configuration, internal configuration, etc. accessible for
other internal services.

By default, Museum runs in local environment, thus `local.yaml` configuration is
loaded.

If `ENVIRONMENT` environment variable is set (say, to `production`), Museum will
attempt to load `configurations/production.yaml`.

If `credentials-file` is defined and found, it overrides the defaults.

Use `museum.yaml` file for declaring configuration over `local.yaml`.

All configuration values can be overridden via environment variables using the
`ENTE_` prefix and replacing dots (`.`) or hyphens (`-`) with underscores (`_`).

Museum reads configuration from `museum.yaml`. Any environment variables
prefixed with `ENTE_` takes precedence.

For example,

```yaml
s3:
    b2-eu-cen:
        endpoint:
```

in `museum.yaml` is read as `s3.b2-eu-cen.endpoint` by Museum.

`ENTE_S3_B2_EU_CEN_ENDPOINT` declared as environment variable is same as the
above and `ENTE_S3_B2_EU_CEN_ENDPOINT` overrides `s3.b2-eu-cen.endpoint`.

### General Settings

| Variable             | Description                                               | Default            |
| -------------------- | --------------------------------------------------------- | ------------------ |
| `credentials-file`   | Path to optional credentials override file                | `credentials.yaml` |
| `credentials-dir`    | Directory to look for credentials (TLS, service accounts) | `credentials/`     |
| `billing-config-dir` | Directory for billing configuration files                 | `data/billing/`    |
| `log-file`           | Log output path. Required in production.                  | `""`               |

### HTTP

| Variable       | Description                                                                 | Default |
| -------------- | --------------------------------------------------------------------------- | ------- |
| `http.port`    | HTTP port. Only effective when `use-tls` is false; TLS always binds to 443. | `8080`  |
| `http.use-tls` | Enables TLS and binds to port 443                                           | `false` |

### App Endpoints

The web apps for Ente (Accounts, Cast, Albums, Share, Paste, Embed) use
different endpoints.

These endpoints are configurable in `museum.yaml` under the apps.\* section.

Upon configuration, the application will start utilizing the specified endpoints
instead of Ente's production instances or local endpoints (overridden values
used for Compose and quickstart for ease of use.)

| Variable                   | Description                                             | Default                    |
| -------------------------- | ------------------------------------------------------- | -------------------------- |
| `apps.public-albums`       | Albums app base endpoint for public sharing             | `https://albums.ente.io`   |
| `apps.public-locker`       | Public Locker (share) app base endpoint                 | `https://share.ente.io`    |
| `apps.public-paste`        | Ente Paste app base endpoint                            | `https://paste.ente.io`    |
| `apps.cast`                | Cast app base endpoint                                  | `https://cast.ente.io`     |
| `apps.embed-albums`        | Embed app base endpoint for embedded sharing            | `https://embed.ente.io`    |
| `apps.accounts`            | Accounts app base endpoint (used for passkey-based 2FA) | `https://accounts.ente.io` |
| `apps.family`              | Family portal base endpoint                             | `https://family.ente.io`   |
| `apps.public-memories`     | Public memory shares base endpoint                      | `https://memories.ente.io` |
| `apps.custom-domain.cname` | Custom domain CNAME for user-facing links               | `my.ente.io`               |

### Database

The `db` section is used for configuring database connectivity. Ensure you
provide correct credentials for proper connectivity within Museum.

| Variable      | Description                | Default     |
| ------------- | -------------------------- | ----------- |
| `db.host`     | DB hostname                | `localhost` |
| `db.port`     | DB port                    | `5432`      |
| `db.name`     | Database name              | `ente_db`   |
| `db.sslmode`  | SSL mode for DB connection | `disable`   |
| `db.user`     | Database username          |             |
| `db.password` | Database password          |             |
| `db.extra`    | Additional DSN parameters  |             |

### Object Storage

The `s3` section within `museum.yaml` is by default configured to use local
MinIO buckets when using `quickstart.sh` or Docker Compose.

If you wish to use an external S3 provider with SSL, you can edit the configuration with
your provider's credentials, and set `s3.are_local_buckets` to `false`. Additionally, you can configure this for specific buckets in the corresponding bucket sections in the Compose file.

If you are using default MinIO, it is accessible at port `3200`. Web Console can
be accessed by enabling port `3201` in the Compose file.

For more information on object storage configuration, check our
[documentation](/self-hosting/administration/object-storage).

If you face any issues related to uploads then check out
[CORS](/self-hosting/administration/object-storage#cors-cross-origin-resource-sharing)
and [troubleshooting](/self-hosting/troubleshooting/uploads) sections.

#### Global S3 Settings

| Variable                   | Description                                                                                                  | Default                  |
| -------------------------- | ------------------------------------------------------------------------------------------------------------ | ------------------------ |
| `s3.are_local_buckets`     | Enable local bucket workarounds (disables SSL, uses path-style URLs, skips GLACIER storage class)            | `false`                  |
| `s3.use_path_style_urls`   | Use path-style S3 URLs instead of subdomain-style (required for MinIO)                                       | `false`                  |
| `s3.hot_storage.primary`   | Override primary hot storage DC (must be a valid bucket ID, see below)                                       | `b2-eu-cen`              |
| `s3.hot_storage.secondary` | Override secondary hot storage DC                                                                            | `wasabi-eu-central-2-v3` |
| `s3.derived-storage`       | Override derived storage DC (embeddings, previews). Defaults to the primary hot storage DC if not specified. |                          |

#### Bucket Configuration

Each bucket is identified by a fixed key name. The names are historical and do
not need to correspond to the actual provider or region — any S3-compatible
provider works.

Valid bucket IDs: `b2-eu-cen`, `wasabi-eu-central-2-v3`, `scw-eu-fr-v3`,
`wasabi-eu-central-2-derived`, `b5`, `b6`

If replication is disabled (the default), only the primary hot storage bucket
needs valid credentials.

For each bucket `{id}`, the following keys are available:

| Variable                               | Description                                      | Default |
| -------------------------------------- | ------------------------------------------------ | ------- |
| `s3.{id}.key`                          | S3 access key                                    |         |
| `s3.{id}.secret`                       | S3 secret key                                    |         |
| `s3.{id}.endpoint`                     | S3 endpoint URL                                  |         |
| `s3.{id}.region`                       | S3 region                                        |         |
| `s3.{id}.bucket`                       | Bucket name                                      |         |
| `s3.{id}.use_path_style_urls`          | Per-bucket override for path-style URLs          |         |
| `s3.{id}.are_local_buckets`            | Per-bucket override for local bucket workarounds |         |
| `s3.{id}.disable_ssl`                  | Per-bucket override to disable SSL               |         |
| `s3.wasabi-eu-central-2-v3.compliance` | Enable compliance lock handling on delete        | `true`  |

### Encryption Keys

These values are used for encryption of user e-mails. Default values are
provided by Museum.

They are generated by random in quickstart script, so no intervention is
necessary if using quickstart.

However, if you are using Ente for long-term needs and you have not installed
Ente via quickstart, consider generating values for these along with [JWT](#jwt)
by following the steps described below:

```shell
# If you have not cloned already
git clone https://github.com/ente-io/ente

# Generate the values
cd ente/server
go run tools/gen-random-keys/main.go
```

| Variable         | Description                    | Default     |
| ---------------- | ------------------------------ | ----------- |
| `key.encryption` | Key for encrypting user emails | Pre-defined |
| `key.hash`       | Hash key                       | Pre-defined |

### JWT

| Variable     | Description             | Default    |
| ------------ | ----------------------- | ---------- |
| `jwt.secret` | Secret for signing JWTs | Predefined |

### Email

You may wish to send emails for verification codes instead of
[hardcoding them](/self-hosting/administration/users#use-hardcoded-otts). In
such cases, you can configure SMTP (or Zoho Transmail, for bulk emails).

Set the host and port accordingly with your credentials in `museum.yaml`

You may skip the username and password if using a local relay server.

```yaml
smtp:
    host:
    port:
    # Optional username and password if using local relay server
    username:
    password:
    # Email address used for sending emails (this mail's credentials have to be provided)
    email:
    # Optional name for sender
    sender-name:
    # Optional encryption
    encryption:
```

| Variable           | Description                  | Default |
| ------------------ | ---------------------------- | ------- |
| `smtp.host`        | SMTP server host             |         |
| `smtp.port`        | SMTP server port             |         |
| `smtp.username`    | SMTP auth username           |         |
| `smtp.password`    | SMTP auth password           |         |
| `smtp.email`       | Sender email address         |         |
| `smtp.sender-name` | Custom name for email sender |         |
| `smtp.encryption`  | Encryption method (tls, ssl) |         |
| `transmail.key`    | Zeptomail API key            |         |

### Listmonk (Optional)

[Listmonk](https://listmonk.app/) is an open-source, self-hosted mailing list
manager. If configured, Museum can add newly registered users to your Listmonk
mailing lists.

| Variable              | Description         | Default |
| --------------------- | ------------------- | ------- |
| `listmonk.server-url` | Listmonk server URL |         |
| `listmonk.username`   | Listmonk username   |         |
| `listmonk.password`   | Listmonk password   |         |
| `listmonk.list-ids`   | List IDs (array)    | `[]`    |

### WebAuthn Passkey Support

| Variable             | Description                  | Default                     |
| -------------------- | ---------------------------- | --------------------------- |
| `webauthn.rpid`      | Relying Party ID             | `localhost`                 |
| `webauthn.rporigins` | Allowed origins for WebAuthn | `["http://localhost:3001"]` |

### Internal

| Variable                                     | Description                                                                                                                                                             | Default |
| -------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------- |
| `internal.silent`                            | Suppress external effects (e.g. email alerts)                                                                                                                           | `false` |
| `internal.trusted-client-ip-header`          | Request header trusted by gin’s `TrustedPlatform` when the server runs behind a proxy (leave empty to use gin’s default order: X-Forwarded-For, X-Real-IP, remote addr) |         |
| `internal.health-check-url`                  | External healthcheck URL                                                                                                                                                |         |
| `internal.hardcoded-ott`                     | Predefined OTPs for testing                                                                                                                                             |         |
| `internal.hardcoded-ott.emails`              | E-mail addresses with hardcoded OTTs                                                                                                                                    | `[]`    |
| `internal.hardcoded-ott.local-domain-suffix` | Suffix for which hardcoded OTT is to be used                                                                                                                            |         |
| `internal.hardcoded-ott.local-domain-value`  | Hardcoded OTT value for the above suffix                                                                                                                                |         |
| `internal.admins`                            | List of admin user IDs                                                                                                                                                  | `[]`    |
| `internal.admin`                             | Single admin user ID (see note below)                                                                                                                                   |         |
| `internal.disable-registration`              | Disable user registration                                                                                                                                               | `false` |

> **Note on `internal.admins` vs `internal.admin`:** Viper has known
> limitations when reading array/slice values from environment variables. If you
> configure Museum entirely via environment variables (e.g., in a Kubernetes or
> GitOps setup), use the singular `internal.admin` (`ENTE_INTERNAL_ADMIN`) to
> set a single admin user ID instead of the plural `internal.admins`.

### Replication

By default, replication of objects (photos, thumbnails, videos) is disabled and
only one bucket is used.

To enable replication, set `replication.enabled` to `true`. For this to work, 3
buckets have to be configured in total.

| Variable                             | Description                                    | Default           |
| ------------------------------------ | ---------------------------------------------- | ----------------- |
| `replication.enabled`                | Enable replication across buckets              | `false`           |
| `replication.worker-url`             | Cloudflare Worker for replication              |                   |
| `replication.worker-count`           | Number of goroutines for replication           | `6`               |
| `replication.tmp-storage`            | Temp directory for replication                 | `tmp/replication` |
| `replication.file-data.worker-count` | Number of goroutines for file-data replication | `6`               |
| `replication.file-data.tmp-storage`  | Temp directory for file-data replication       | `tmp/replication` |

### Background Jobs

This configuration is for enabling background cron jobs for tasks such as
sending mails, removing unused objects (clean up) and worker configuration for
the same.

| Variable                                      | Description                             | Default |
| --------------------------------------------- | --------------------------------------- | ------- |
| `jobs.cron.skip`                              | Skip all cron jobs                      | `false` |
| `jobs.remove-unreported-objects.worker-count` | Workers for removing unreported objects | `1`     |
| `jobs.clear-orphan-objects.enabled`           | Enable orphan cleanup                   | `false` |
| `jobs.clear-orphan-objects.prefix`            | Prefix filter for orphaned objects      |         |
