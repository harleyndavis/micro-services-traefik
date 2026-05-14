# URL Shortener - Example App

A Django-based URL shortener microservice with a clean web UI and REST API. This app demonstrates a complete microservice setup with Traefik routing, PostgreSQL database, and containerized deployment.

## Features

- 🔗 Create shortened URLs with auto-generated 6-character codes
- 📊 Track click statistics for each shortened link
- 🎨 Clean, responsive web interface
- 🔌 REST API for programmatic access
- 📦 PostgreSQL database for persistence
- 🐳 Docker & Docker Compose ready
- 🔀 Traefik integration for reverse proxy routing

## Quick Start

### 1. Copy the environment file

```bash
cd example-app
cp .env.example .env
```

### 2. Ensure `traefik/.env` is configured

The compose file reads `../traefik/.env` automatically for `TRAEFIK_DASHBOARD_HOST`, `ACME_EMAIL`, and `CERT_RESOLVER`. No changes to `traefik/.env` are needed beyond the standard Traefik setup — app-specific settings live in `example-app/.env`.

### 3. Make sure the Traefik `proxy` network exists

From the traefik directory:

```bash
docker network create proxy
```

### 4. Start the stack

From the `example-app` directory:

```bash
docker compose up -d
```

### 5. Run migrations (first time only)

```bash
docker compose -f docker-compose.yml exec app python manage.py migrate
```

### 6. Access the app

- **Web UI**: `https://shortener.dev.localhost` (local) or `https://shortener.yourdomain.com` (production)
- **API**: `https://shortener.dev.localhost/api/`

## API Endpoints

### Shorten a URL

```bash
curl -X POST https://shortener.dev.localhost/api/links/shorten/ \
  -H "Content-Type: application/json" \
  -d '{"original_url": "https://example.com/very/long/url"}'
```

Response:
```json
{
  "id": 1,
  "original_url": "https://example.com/very/long/url",
  "short_code": "abc123",
  "short_url": "https://shortener.dev.localhost/api/s/abc123",
  "clicks": 0,
  "created_at": "2026-05-01T12:00:00Z"
}
```

### List all shortened links

```bash
curl https://shortener.dev.localhost/api/links/list_all/
```

### Get statistics

```bash
curl https://shortener.dev.localhost/api/links/stats/
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
# This will redirect to the original URL and increment the click counter
curl -L https://shortener.dev.localhost/s/abc123
```

## Project Structure

```
example-app/
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
├── manage.py               # Django CLI
├── Dockerfile              # Container image definition
├── docker-compose.yml      # Local compose setup
├── requirements.txt        # Python dependencies
└── README.md              # This file
```

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

3. Create a `.env` file with your settings or run with defaults

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
docker compose -f docker-compose.yml logs -f app
docker compose -f docker-compose.yml logs -f db
```

### Stopping the stack

```bash
docker compose -f docker-compose.yml down
```

### Resetting the database

```bash
docker compose -f docker-compose.yml down -v
docker compose -f docker-compose.yml up -d
docker compose -f docker-compose.yml exec app python manage.py migrate
```

## Production Hardening

When deploying to production:

1. Generate a strong `DJANGO_SECRET_KEY`
2. Set `DEBUG=False`
3. Use a strong database password
4. Set `CERT_RESOLVER=letsencrypt` and `TRAEFIK_DASHBOARD_HOST` to your real domain in `traefik/.env` — `ALLOWED_HOSTS`, `CORS_ALLOWED_ORIGINS`, and `CSRF_TRUSTED_ORIGINS` derive from it automatically
5. Implement rate limiting on the API
6. Use managed PostgreSQL or regular backups

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
