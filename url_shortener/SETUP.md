# URL Shortener - Setup Guide

Follow these steps to get your URL shortener app running.

## Prerequisites

- Docker and Docker Compose installed
- Your Traefik stack set up (from the `traefik/` directory)
- A working `.env` file in the `traefik/` directory

## Step 1: Prepare Your Environment Files

`traefik/.env` is the single source of truth for `DOMAIN`, `ACME_EMAIL`, and `CERT_RESOLVER`. The url_shortener compose reads it automatically — you do **not** need to duplicate those values here.

### In `url_shortener/.env`

Copy the example file:

```bash
cd url_shortener
cp .env.example .env
```

The defaults work for local development. Edit only the app-specific values:

```env
DEBUG=True
DJANGO_SECRET_KEY=your-secret-key-here
DB_HOST=db
DB_PORT=5432
DB_NAME=shortener
DB_USER=postgres
DB_PASSWORD=postgres
```

`ALLOWED_HOSTS`, `CORS_ALLOWED_ORIGINS`, and `CSRF_TRUSTED_ORIGINS` are derived automatically from `DOMAIN` in `docker-compose.yml` — no need to set them manually. For production, only `traefik/.env` needs updating.

## Step 2: Create the Traefik Network (if not already created)

This network is shared between Traefik and your microservices:

```bash
docker network create proxy
```

## Step 3: Start the Application

From the `url_shortener/` directory:

```bash
docker compose up -d
```

Or from the repo root using the Makefile:

```bash
make up-shortener
```

This will:
- Pull PostgreSQL image
- Build the Django app image
- Start both services
- Run database migrations automatically
- Collect static files

## Step 4: Verify It's Running

Check that containers are running:

```bash
docker compose ps
```

You should see `app` and `db` containers in the RUNNING state.

Check the logs:

```bash
docker compose logs -f app
```

You should see something like:
```
Starting application...
[2026-05-01 12:00:00 +0000] [1] [INFO] Starting gunicorn 21.2.0
[2026-05-01 12:00:00 +0000] [1] [INFO] Listening at: http://0.0.0.0:8000
```

## Step 5: Access the Application

Open your browser and go to:

**Local development**: `https://short.dev.localhost`

(If you get a certificate warning, that's normal for self-signed certs — click "Advanced" and "Proceed")

You should see the URL Shortener interface with a form to shorten URLs.

## Testing the API

### Create a shortened link

```bash
curl -X POST https://short.dev.localhost/api/links/shorten/ \
  -H "Content-Type: application/json" \
  -d '{"original_url": "https://github.com/python/cpython"}'
```

Response:
```json
{
  "id": 1,
  "original_url": "https://github.com/python/cpython",
  "short_code": "aBc12D",
  "short_url": "https://short.dev.localhost/s/aBc12D",
  "clicks": 0,
  "qr_scans": 0,
  "created_at": "2026-05-01T12:00:00Z"
}
```

### Get statistics

```bash
curl https://short.dev.localhost/api/links/stats/
```

Response:
```json
{
  "total_links": 1,
  "total_clicks": 0,
  "total_qr_scans": 0
}
```

## Troubleshooting

### Certificate errors on HTTPS

Your local setup uses self-signed certificates from mkcert. If you haven't generated them yet, see the `traefik/` README for mkcert setup instructions.

### Database connection errors

Make sure the `db` container is healthy:

```bash
docker compose exec db pg_isready
```

If not healthy, check logs:

```bash
docker compose logs db
```

### Port 8000 already in use

If port 8000 is in use, update the port mapping in `docker-compose.yml`:

```yaml
services:
  app:
    ports:
      - "8001:8000"  # Map external 8001 to container 8000
```

### Static files not loading

Rebuild the image:

```bash
docker compose build --no-cache app
docker compose up -d app
```

## Development Tips

### Access the Django shell

```bash
docker compose exec app python manage.py shell
```

### Create a superuser for admin panel

From the repo root:

```bash
make superuser
```

Or directly (app must be running):

```bash
docker compose exec app python manage.py createsuperuser
```

Then visit: `https://short.dev.localhost/admin/`

### Run custom management commands

```bash
docker compose exec app python manage.py <command>
```

### View database directly (with psql)

```bash
docker compose exec db psql -U postgres -d shortener
```

## Next Steps

1. **Add authentication**: Extend the Link model with a user field to track who created each link
2. **Custom short codes**: Allow users to specify their own short codes (vanity URLs)
3. **Link expiration**: Add an expiration date to links
4. **Analytics**: Create a dashboard showing top links and traffic patterns
5. **Rate limiting**: Add API rate limiting to prevent abuse

See the README.md for more details on the app structure and API endpoints.
