# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Micro Projects with Traefik** is an infrastructure-as-code starter stack built around Traefik v3.x as a reverse proxy. It supports both local development (mkcert self-signed certs) and production VPS deployment (Let's Encrypt), controlled entirely by `.env` values — no changes to `docker-compose.yml` are needed between environments.

## Starting the Stack

All `make` commands run from the **repo root**.

**One-time setup:**
```bash
make setup          # copies .env.example → .env and url_shortener/.env.example → url_shortener/.env
# edit .env with your DOMAIN, brand info, etc.
```

**Local development (first-time cert setup):**
```bash
mkcert -install
mkcert -cert-file traefik/certs/dev.localhost.pem \
       -key-file traefik/certs/dev.localhost-key.pem \
       dev.localhost "*.dev.localhost" ::1
```

**Start everything:**
```bash
make up
```

**Verify / Logs:**
```bash
make ps
make logs-traefik
make logs-static
make logs-shortener
```

## Architecture

```
.env.example                  # Single source of truth: DOMAIN, TLS, brand/personal vars
Makefile                      # Orchestrates all services; passes root .env to every compose call

traefik/
├── docker-compose.yml        # Traefik + whoami (dev profile); all routing via Docker labels
├── .env.example              # Stub — points to root .env
├── certs/                    # mkcert certs (gitignored *.pem)
├── dynamic/
│   ├── tls.yaml              # File-provider TLS cert paths (local dev only)
│   └── dashboard-users.htpasswd
└── letsencrypt/              # acme.json written here at runtime (gitignored)

static_site/                  # nginx landing page at www.<DOMAIN>
├── docker-compose.yml        # nginx:alpine; SSI enabled via nginx.conf.template; env_file: ../.env
├── nginx.conf.template       # envsubst-processed at startup; sets SSI + sub_filter rules
├── .env.example              # Stub — points to root .env
└── html/
    ├── _partials/            # Shared HTML fragments (header, footer, theme script)
    │   ├── header.html       # Nav + theme toggle; {{ HOME_URL }} etc. resolved per-service
    │   ├── footer.html
    │   └── theme-script.html # Theme toggle behaviour + active-nav JS
    ├── css/site.css          # Shared stylesheet loaded cross-origin by url_shortener
    └── index.html            # Landing page; SSI-includes the partials

url_shortener/                # Django + PostgreSQL URL shortener microservice
├── docker-compose.yml        # app + db services; env_file: [../.env, .env]; joins external `proxy` network
├── Dockerfile                # python:3.11-slim; runs gunicorn on port 8000
├── .env.example              # Service-specific secrets only: DEBUG, DJANGO_SECRET_KEY, DB_*
├── manage.py
├── requirements.txt
├── shortener/                # Django project (wsgi, settings)
├── links/                    # URL shortening app (models, views, serializers)
└── templates/
    ├── base.html             # Shared shell: {% include "partials/..." %} for header/footer
    ├── shortener.html        # {% extends "base.html" %} — URL shortener UI
    └── qr_generator.html     # {% extends "base.html" %} — standalone QR generator
```

### Dual-mode configuration

All services share a single root `.env`. The Makefile passes it to every `docker compose` call via `--env-file .env`, and each service's compose file loads it into containers via `env_file: ../.env`. Three keys control the local↔production switch:

| Key | Local dev | Production |
|---|---|---|
| `DOMAIN` | `dev.localhost` | `yourdomain.com` |
| `ACME_EMAIL` | *(empty)* | `you@example.com` |
| `CERT_RESOLVER` | *(empty)* | `letsencrypt` |

When `CERT_RESOLVER` is empty, Traefik uses the static cert from `dynamic/tls.yaml`. When set to `letsencrypt`, it uses the ACME resolver and ignores the file provider cert.

### Adding a new service

When adding a new service, load the root `.env` into it the same way `static_site` does:

```yaml
env_file:
  - ../.env
```

And run it via the Makefile with `--env-file .env` so `${DOMAIN}` and `${CERT_RESOLVER}` are available for compose label interpolation.

### url_shortener

The first microservice in the stack. Runs Django + Gunicorn behind Traefik at `short.<DOMAIN>`.

**Start (local dev):**
```bash
make up-shortener
```

**Key behaviours:**
- `ALLOWED_HOSTS`, `CORS_ALLOWED_ORIGINS`, and `CSRF_TRUSTED_ORIGINS` are all derived from `DOMAIN` — no manual list needed.
- `HOME_URL` is also derived from `DOMAIN` as `https://www.{DOMAIN}` and injected into every template via the context processor. Nav "Home" links and the brand link point here so they exit the shortener subdomain to the main site. No separate env var required.
- `staticfiles` is a named Docker volume shared between the build step and the running container to avoid bind-mount permission errors.
- The `db` healthcheck uses `pg_isready -U <user> -d <dbname>` so the app waits for the correct database, not just the server process.
- `CERT_RESOLVER` is set on the router label (`tls.certresolver=${CERT_RESOLVER:-}`); an empty value disables ACME and falls back to the Traefik file-provider cert.

### QR code integration

QR codes are generated client-side using `qrcodejs` (loaded from CDN).

**Shortener UI (`/`):** After a URL is shortened, a QR code is auto-generated inline. The encoded URL is `<short_url>?src=qr` so scans are tracked separately from direct link clicks in the `Link.qr_scans` field. The stats box shows QR Scans alongside Total Links and Total Clicks.

**Standalone generator (`/qr/`):** Full-featured QR generator supporting text/URL, vCard, Wi-Fi, email, and SMS payloads. Accepts a `?url=` query parameter — the shortener's "Full Generator" button links here with the short URL pre-filled and auto-generated.

**Tracking:** The redirect view at `/s/<code>` checks `?src=qr` and increments `qr_scans` instead of `clicks`. The `/api/links/stats/` endpoint exposes `total_qr_scans`.

## Branching Conventions

**Never commit directly to `main`.** All new work — features, fixes, experiments — must start from a fresh branch.

Before writing any code or editing any file, check the current branch with `git branch --show-current`. If it is `main`, create and switch to a new branch first.

**Naming convention:**
| Work type | Prefix | Example |
|---|---|---|
| New feature | `feature/` | `feature/add-analytics-dashboard` |
| Bug fix | `fix/` | `fix/redirect-loop-on-short-url` |
| Chore / infra / deps | `chore/` | `chore/upgrade-traefik-v3` |
| Documentation | `docs/` | `docs/production-hardening-notes` |

Use lowercase kebab-case after the prefix. Branch names should be descriptive enough that the purpose is obvious without reading the commits.

**One-time local setup (run after cloning):**
```bash
git config core.hooksPath .githooks
```
This activates the `pre-push` hook in `.githooks/`, which blocks direct pushes to `main` and prompts you to use a feature branch instead.

**Workflow:**
1. `git checkout -b <prefix>/<short-description>` before touching any file.
2. Commit incrementally with clear messages as work progresses.
3. Open a PR against `main` when the feature is complete and tested.
4. Do not squash or rebase published branches without explicit instruction.

## Production Hardening

See `docs/production-hardening.md` for the full checklist (IP allowlist for dashboard, ufw rules, Docker socket exposure, SSH hygiene, etc.).

## CI/CD Pattern

See `docs/automating-deployment-summary.md` for the GitHub Actions + Watchtower pipeline. Workflow triggers on semantic version tags (`*.*.*`), publishes to `ghcr.io`, and Watchtower auto-deploys on the VPS.
