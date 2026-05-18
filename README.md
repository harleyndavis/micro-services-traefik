# Micro Services with Traefik

This repository contains a small Traefik reverse-proxy stack that supports both local development (using locally-trusted certs) and production deployment (using Let's Encrypt). The same `docker-compose.yml` handles both — the difference is entirely in `.env`.

Current layout:

```text
Makefile              ← top-level commands for managing all services
docs/
  automating-deployment-summary.md
  production-hardening.md
  runbook.md
traefik/
  .env.example
  docker-compose.yml
  certs/
  dynamic/
    dashboard-users.htpasswd.example
    tls.yaml
  letsencrypt/
static_site/          ← nginx serving the www landing page
  docker-compose.yml
  .env.example
  html/
url_shortener/        ← Django URL shortener microservice
  docker-compose.yml
  Dockerfile
  .env.example
```

The active Traefik stack lives in `traefik/`.

## Quick Start

The root `Makefile` manages all services. From the repo root:

```bash
make setup   # copy .env.example → .env for each service
make up      # start traefik, static_site, and url_shortener
make down    # stop everything
make ps      # container status across all services
make help    # full target list
```

Individual services: `make up-traefik`, `make up-static`, `make up-shortener`, etc.

---

## What This Stack Does

- Runs Traefik on ports `80` and `443`
- Redirects HTTP to HTTPS
- Exposes the Traefik dashboard behind basic auth
- Loads dynamic Traefik config from `traefik/dynamic/tls.yaml`
- Includes a `whoami` test container for validating routing
- Supports **local dev** (file-based certs via `traefik/certs/`) and **production** (Let's Encrypt via TLS challenge)

**Services behind Traefik:**

| Service | Host | Description |
|---|---|---|
| Traefik dashboard | `dashboard.<host>` | Routing UI, basic auth protected |
| static_site | `www.<host>` | nginx landing page |
| url_shortener | `short.<host>` | Django URL shortener with QR codes |

---

## Local Development

Local dev uses locally-trusted certificates (e.g. generated with [mkcert](https://github.com/FiloSottile/mkcert)) instead of Let's Encrypt. No public DNS or open ports are required.

The local hostname used here is `dev.localhost`. This allows both `whoami.dev.localhost` and `dev.localhost/whoami` to be served over HTTPS, which helps with local testing.
Using a bare `whoami.localhost` hostname was tried first but remained insecure — top-level domain wildcards do not resolve to 127.0.0.1. Using `dev.localhost` as the base domain allows wildcard certificates to cover additional services as they are added.

### Prerequisites

- Docker and Docker Compose installed locally
- [mkcert](https://github.com/FiloSottile/mkcert) installed and its local CA trusted in your browser

### 1. Generate Local Certificates

```bash
mkcert -install
mkcert -cert-file traefik/certs/dev.localhost.pem -key-file traefik/certs/dev.localhost-key.pem dev.localhost "*.dev.localhost" ::1
```

This creates stable files (`dev.localhost.pem` and `dev.localhost-key.pem`) and includes SANs for `dev.localhost` and any `*.dev.localhost` subdomain such as `dashboard.dev.localhost` and `whoami.dev.localhost`.

`traefik/dynamic/tls.yaml` already points at these file names:

```yaml
tls:
  certificates:
    - certFile: /certs/dev.localhost.pem
      keyFile: /certs/dev.localhost-key.pem
```

If you use different file names, update `tls.yaml` to match.

If Chrome still shows "Not secure" after generating certs, restart Chrome completely and verify the mkcert root CA is installed in the Windows "Trusted Root Certification Authorities" store.

### 2. Configure `.env`

Quick and dirty way is just to use the .env.example file.

```bash
docker compose --env-file .env.example -f docker-compose.yml up -d --build
```

Otherwise you can set up the .env file like you would in production. This is helpful if you don't want to run the docker compose yourself in the terminal.

```bash
cp .env.example .env
```

Leave `ACME_EMAIL` and `CERT_RESOLVER` empty (their defaults). Set the host:

```env
DOMAIN=dev.localhost
ACME_EMAIL=
CERT_RESOLVER=
```

With these values Traefik serves TLS using the file-provider certs in `./certs/` and does not contact Let's Encrypt.

### 3. Set Up The Admin Password File

The dashboard uses file-based basic auth. A dummy credentials file is included to make local setup easier.

Copy the example file:

```bash
cp traefik/dynamic/dashboard-users.htpasswd.example traefik/dynamic/dashboard-users.htpasswd
```

The example file contains a dummy `admin` account with the password `choose-good-password`. For local development this is fine to use as-is.

To set your own password, generate a bcrypt entry with Docker and replace the file contents:

```bash
docker run --rm httpd:2.4-alpine htpasswd -nbB admin 'choose-a-strong-password'
```

> The compose file uses `basicauth.usersfile` (a mounted file) rather than inlining the hash. This avoids Docker Compose `$` interpolation issues — no escaping required.

> **Note:** `dashboard-users.htpasswd` is gitignored. The `.example` file is committed as a starter only — basic auth is not intended as the long-term auth solution for this stack.

### 4. Start The Stack

From `traefik/`:

```bash
docker compose --env-file .env -f docker-compose.yml up -d
```

### 5. Verify

- `https://dashboard.dev.localhost/` — prompts for basic auth and loads the Traefik UI
- `https://whoami.dev.localhost/` — reaches the test container

---

## Production (VPS + Let's Encrypt)

Production uses Let's Encrypt's TLS challenge to obtain and renew certificates automatically. Port `80` must be publicly reachable for the challenge to succeed.

### Prerequisites

- A Linux VPS with Docker and Docker Compose
- DNS records pointing your chosen hostnames to the VPS public IP
- Ports `80` and `443` open in the VPS firewall/security group

### 1. Install Docker (if needed)

Typical Ubuntu setup:

```bash
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo $VERSION_CODENAME) stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo usermod -aG docker $USER
```

After adding your user to the `docker` group, sign out and back in before running Docker without `sudo`.

If you use `ufw`, allow web traffic:

```bash
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
```

### 2. Copy The Repository To The VPS

Example with `scp`:

```bash
scp -r ./OCIDDD your-user@your-server:/opt/
```

Example with `rsync`:

```bash
rsync -av --delete ./OCIDDD/ your-user@your-server:/opt/OCIDDD/
```

### 3. Configure `.env`

On the VPS:

```bash
cd /opt/OCIDDD/traefik
cp .env.example .env
```

Edit `.env` and set all three values:

```env
DOMAIN=example.com
ACME_EMAIL=you@example.com
CERT_RESOLVER=letsencrypt
```

With `CERT_RESOLVER=letsencrypt` set, the dashboard and whoami routers will request Let's Encrypt certificates for their hostnames. The `letsencrypt/acme.json` file is where Traefik stores issued certificates between restarts.

> The `traefik/certs/` directory and `dynamic/tls.yaml` are still mounted but have no effect when `CERT_RESOLVER=letsencrypt` is active — Let's Encrypt certs take precedence for those routers.

### 4. Set Up The Admin Password File

Copy the example file and replace the dummy hash with a strong password:

```bash
cp traefik/dynamic/dashboard-users.htpasswd.example traefik/dynamic/dashboard-users.htpasswd
docker run --rm httpd:2.4-alpine htpasswd -nbB admin 'choose-a-strong-password'
```

Replace the contents of `traefik/dynamic/dashboard-users.htpasswd` with the printed line. Do not use the example dummy password in production.

### 5. Start The Stack

```bash
docker compose --env-file .env -f docker-compose.yml up -d
```

To preview the rendered config before starting:

```bash
docker compose --env-file .env -f docker-compose.yml config
```

### 6. Verify

Check containers and logs:

```bash
docker compose ps
docker compose logs -f traefik
```

Then verify:

- `https://dashboard.example.com/` — prompts for basic auth and loads the Traefik UI
- `https://whoami.example.com/` — reaches the test container

### Production Readiness

This setup is not intended as a fully hardened production platform. It is better thought of as a practical starting point for small personal projects, demos, or low-stakes self-hosting where convenience matters more than operational rigor.

If you plan to use it for anything with meaningful uptime, security, compliance, or business impact requirements, you should treat it as a base to extend rather than something production-ready as-is.

For a starting follow-up checklist, see `docs/production-hardening.md`.

---

## Notes

- The dashboard router serves `api@internal` at `dashboard.<DOMAIN>` — this covers both the UI and the `/api` paths the UI depends on.
- `docs/automating-deployment-summary.md` contains broader deployment notes, but this README is the source of truth for the Traefik stack.
- See `static_site/README.md` for the landing page service.
- See `url_shortener/README.md` for the URL shortener (QR codes, API docs, dev tips).
