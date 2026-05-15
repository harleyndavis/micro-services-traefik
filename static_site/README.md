# static_site

An nginx container serving the `www.<host>` landing page. It hosts the shared `site.css` stylesheet and the shared HTML partials (header, footer, theme script) that are consumed by both this site and the `url_shortener` service, keeping all services visually consistent from a single source of truth.

## What it serves

- `www.<DOMAIN>` — the main landing page (`html/index.html`)
- `www.<DOMAIN>/css/site.css` — shared stylesheet (loaded cross-origin by url_shortener templates)
- `html/_partials/` — shared HTML fragments (header, footer, theme script); served internally via nginx SSI and volume-mounted read-only into the url_shortener container for Django template inclusion

All files under `html/` are served read-only; no build step is needed.

## Shared partials and SSI

The `html/_partials/` directory contains HTML fragments that are the single source of truth for global UI components across the entire stack:

| File | Purpose |
|---|---|
| `_partials/header.html` | Site header: brand link, nav, theme toggle buttons |
| `_partials/footer.html` | Site footer with copyright year |
| `_partials/theme-script.html` | Theme toggle logic, year update, and active-nav highlighting |

### How partials are resolved per service

Partials use `{{ HOME_URL }}`, `{{ SHORTENER_URL }}`, and `{{ QR_URL }}` as placeholders. Each service resolves them natively:

- **static_site (nginx)**: `nginx.conf.template` is processed by `envsubst` at container startup, baking `${DOMAIN}` into the nginx config. Then nginx's `sub_filter` replaces the `{{ }}` placeholders in assembled SSI output with absolute URLs derived from `DOMAIN`.
- **url_shortener (Django)**: The `_partials/` directory is volume-mounted into the container at `templates/partials/`. Django's `{% include %}` pulls in the files, and the template engine replaces `{{ HOME_URL }}` etc. using context variables injected by the `assets_url` context processor in `shortener/context_processors.py`.

### nginx.conf.template

`nginx.conf.template` is mounted at `/etc/nginx/templates/default.conf.template`. The official nginx image automatically runs `envsubst` on files in that directory at startup, so `${DOMAIN}` is replaced before nginx starts. The rendered config enables:

- **SSI** (`ssi on`) — assembles pages from `<!--#include virtual="/_partials/..." -->` directives in HTML files
- **Internal `/_partials/` location** — prevents direct browser access to raw partial files
- **`sub_filter`** — replaces `{{ HOME_URL }}`, `{{ SHORTENER_URL }}`, and `{{ QR_URL }}` in the assembled output with real absolute URLs

## Quick Start

From the repo root:

```bash
make up-static
```

Or directly from `static_site/`:

```bash
docker compose --env-file .env up -d
```

## Configuration

Copy the example env file:

```bash
cp .env.example .env
```

`.env.example` contains:

```env
DOMAIN=dev.localhost
CERT_RESOLVER=
```

These mirror the values in `traefik/.env`. For local dev the defaults work as-is. For production, set both to match your Traefik stack.

| Variable | Purpose | Example |
|---|---|---|
| `DOMAIN` | Base hostname for Traefik routing | `dev.localhost` / `yourdomain.com` |
| `CERT_RESOLVER` | TLS cert source (empty = file provider, `letsencrypt` = ACME) | *(empty)* / `letsencrypt` |
| `SITE_NAME` | Brand name shown in header, footer, and page titles | `hrly.sh` |
| `AUTHOR_NAME` | Name shown in the hero `<h1>` and page `<title>` | `Harley Davis` |
| `AUTHOR_EMAIL` | Email address for the contact link | `you@example.com` |
| `GITHUB_URL` | Full GitHub profile URL | `https://github.com/yourname` |
| `GITHUB_HANDLE` | Display handle shown in the social card | `@yourname` |
| `LINKEDIN_URL` | Full LinkedIn profile URL | `https://linkedin.com/in/yourname` |
| `LINKEDIN_HANDLE` | Display handle shown in the social card | `in/yourname` |
| `SITE_TAGLINE` | Footer tagline (use `&amp;` instead of `&`) | `BUILT WITH CAFFEINE &amp; CURIOSITY` |

## Prerequisites

- The `proxy` Docker network must exist (created automatically when the Traefik stack starts)
- Traefik must be running to route `www.<host>` to this container

## Logs

```bash
make logs-static
# or
docker compose logs -f static_site
```
