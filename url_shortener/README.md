# URL Shortener - Example App

A Django-based URL shortener microservice with a clean web UI and REST API. This app demonstrates a complete microservice setup with Traefik routing, PostgreSQL database, and containerized deployment.

## Features

- Create shortened URLs with auto-generated 6-character codes
- Track click statistics for each shortened link
- Clean, responsive web interface
- REST API for programmatic access
- PostgreSQL database for persistence
- Docker & Docker Compose ready
- Traefik integration for reverse proxy routing

## Quick Start

### 1. Copy the environment file

```bash
cd url_shortener
cp .env.example .env
```

Edit `.env` if you need non-default values. At minimum, set a real `DJANGO_SECRET_KEY` for any non-throwaway deployment.

### 2. Make sure the Traefik `proxy` network exists

```bash
docker network create proxy
```

Skip this if you already have the Traefik stack running — it creates the network automatically.

### 3. Make sure the Traefik stack is running

The app registers itself with Traefik via Docker labels. Traefik must be up first.

```bash
cd ../traefik
docker compose --env-file .env up -d
```

### 4. Start the app stack

From the `url_shortener` directory:

```bash
docker compose up -d
```

Migrations and static file collection run automatically on startup. No manual steps needed.

### 5. Access the app

- **Web UI**: `https://short.dev.localhost` (local) or `https://short.yourdomain.com` (production)
- **API**: `https://short.dev.localhost/api/`

## API Endpoints

### Shorten a URL

```bash
curl -X POST https://short.dev.localhost/api/links/shorten/ \
  -H "Content-Type: application/json" \
  -d '{"original_url": "https://example.com/very/long/url"}'
```

Response:
```json
{
  "id": 1,
  "original_url": "https://example.com/very/long/url",
  "short_code": "abc123",
  "short_url": "https://short.dev.localhost/api/s/abc123",
  "clicks": 0,
  "created_at": "2026-05-01T12:00:00Z"
}
```

### List all shortened links

```bash
curl https://short.dev.localhost/api/links/list_all/
```

### Get statistics

```bash
curl https://short.dev.localhost/api/links/stats/
```

Response:
```json
{
  "total_links": 5,
  "total_clicks": 42
}
```

### Redirect via short link

```bash
# Redirects to the original URL and increments the click counter
curl -L https://short.dev.localhost/s/abc123
```

## Project Structure

```
url_shortener/
├── shortener/              # Django project config
│   ├── settings.py         # Settings (uses env vars)
│   ├── urls.py             # URL routing
│   └── wsgi.py             # WSGI entry point
├── links/                  # URL shortening app
│   ├── models.py           # Link model with short code generation
│   ├── serializers.py      # DRF serializers
│   ├── views.py            # API views
│   └── urls.py             # App-level routing
├── templates/
│   └── index.html          # Single-page web UI
├── static/                 # Source static files (served via collectstatic)
├── manage.py               # Django CLI
├── Dockerfile              # Container image definition
├── docker-compose.yml      # Compose stack (app + postgres)
├── .env.example            # Environment variable reference
└── requirements.txt        # Python dependencies
```

### Volumes

- `./:/app` — bind-mounts source code for live reloading during development
- `staticfiles:/app/staticfiles` — named volume; `collectstatic` writes here at startup so the bind-mount's host permissions don't interfere
- `postgres_data:/var/lib/postgresql/data` — persistent database storage

## Development

### Running locally (without Docker)

1. Create a Python virtual environment:
   ```bash
   python3 -m venv venv
   source venv/bin/activate  # or `venv\Scripts\activate` on Windows
   ```

2. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```

3. Create a `.env` file with your settings or run with defaults.

4. Run migrations:
   ```bash
   python manage.py migrate
   ```

5. Start the development server:
   ```bash
   python manage.py runserver
   ```

6. Visit `http://localhost:8000`

### Viewing logs

```bash
docker compose logs -f app
docker compose logs -f db
```

### Stopping the stack

```bash
docker compose down
```

### Resetting the database

```bash
docker compose down -v
docker compose up -d
```

Migrations run automatically on the next startup.

## Production Hardening

When deploying to production:

1. Generate a strong `DJANGO_SECRET_KEY`
2. Set `DEBUG=False`
3. Use a strong database password
4. Set `TRAEFIK_DASHBOARD_HOST` to your real domain — `ALLOWED_HOSTS`, `CORS_ALLOWED_ORIGINS`, and `CSRF_TRUSTED_ORIGINS` derive from it automatically
5. Set `CERT_RESOLVER=letsencrypt` (matches your Traefik `.env`)
6. Implement rate limiting on the API
7. Use managed PostgreSQL or set up regular backups

See `../docs/production-hardening.md` for the full security checklist.

## Next Steps

Ideas for extending this app:

- Add user authentication to track personal shortened links
- Implement API rate limiting
- Add link expiration dates
- Create custom short codes (vanity URLs)
- Build admin dashboard to view all links and stats
- Add QR code generation for shortened links
- Implement link password protection
- Add link preview before redirect
