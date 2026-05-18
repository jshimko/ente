---
title: Environment variables and defaults - Self-hosting
description: "Information about all the configuration variables needed to run Ente along
    with description on default configuration"
---

# Environment variables and defaults

The environment variables needed for running Ente and the default configuration
are documented below:

## Museum Server Environment Variables

All Museum (server) configuration keys can be set as environment variables. The
naming convention is:

1. Add the prefix `ENTE_`
2. Replace dots (`.`) with underscores (`_`)
3. Replace hyphens (`-`) with underscores (`_`)
4. Uppercase everything

For example:

| YAML key                        | Environment variable                 |
| ------------------------------- | ------------------------------------ |
| `db.host`                       | `ENTE_DB_HOST`                       |
| `s3.b2-eu-cen.endpoint`         | `ENTE_S3_B2_EU_CEN_ENDPOINT`         |
| `apps.public-albums`            | `ENTE_APPS_PUBLIC_ALBUMS`            |
| `internal.disable-registration` | `ENTE_INTERNAL_DISABLE_REGISTRATION` |
| `jwt.secret`                    | `ENTE_JWT_SECRET`                    |

Environment variables take precedence over all configuration files. The full
configuration precedence order (highest to lowest):

1. Environment variables with `ENTE_` prefix
2. `museum.yaml` in the working directory
3. Credentials file (`credentials.yaml` or value of `credentials-file`)
4. `configurations/{ENVIRONMENT}.yaml` (base config)

For a complete reference of all configuration keys, see the
[Configuration](/self-hosting/installation/config) page.

> **Note:** The `ENVIRONMENT` variable (default: `local`) selects which base
> config file to load and is read directly from the OS environment, not through
> the `ENTE_` prefix system.

## Cluster Environment Variables

A self-hosted Ente web app only needs the Museum API endpoint. Web app origins are configured in `museum.yaml` under `apps`.

This document outlines the essential environment variables and port mappings of
the web apps.

Here's the list of environment variables that is used by the cluster:

| Service    | Environment Variable  | Description                                                                  | Default Value                   |
| ---------- | --------------------- | ---------------------------------------------------------------------------- | ------------------------------- |
| `web`      | `ENTE_API_ORIGIN`     | Alias for `NEXT_PUBLIC_ENTE_ENDPOINT`. API Endpoint for Ente's API (Museum). | http://localhost:8080           |
| `postgres` | `POSTGRES_USER`       | Username for PostgreSQL database                                             | `pguser`                        |
| `postgres` | `POSTGRES_DB`         | Name of database for use with Ente                                           | `ente_db`                       |
| `postgres` | `POSTGRES_PASSWORD`   | Password for PostgreSQL database's user                                      | Randomly generated (quickstart) |
| `minio`    | `MINIO_ROOT_USER`     | Username for MinIO                                                           | Randomly generated (quickstart) |
| `minio`    | `MINIO_ROOT_PASSWORD` | Password for MinIO                                                           | Randomly generated (quickstart) |

## Default Configuration

Self-hosted Ente clusters have certain default configuration for ease of use,
which is documented below to understand its behavior:

### Ports

The table below lists the default host/container ports used by Ente's web
container and related services. The mapping is of the format
`<host-port>:<container-port>` in the compose file.

If you are using `quickstart.sh`, note that only `3000` (Photos) and `3002`
(Albums) are exposed by default.

| Service                                                  | Type     | Host Port | Container Port |
| -------------------------------------------------------- | -------- | --------- | -------------- |
| Museum                                                   | Server   | 8080      | 8080           |
| Ente Photos                                              | Web      | 3000      | 3000           |
| Ente Accounts                                            | Web      | 3001      | 3001           |
| Ente Albums                                              | Web      | 3002      | 3002           |
| [Ente Auth](https://ente.com/auth/)                      | Web      | 3003      | 3003           |
| [Ente Cast](https://ente.com/help/photos/features/cast/) | Web      | 3004      | 3004           |
| Ente Public Locker                                       | Web      | 3005      | 3005           |
| Ente Embed                                               | Web      | 3006      | 3006           |
| Ente Paste (if deployed separately)                      | Web      | 3008      | 3008           |
| Ente Memories                                            | Web      | 3010      | 3010           |
| MinIO                                                    | S3       | 3200      | 3200           |
| PostgreSQL                                               | Database |           | 5432           |
