# Traefik Operations Runbook

This runbook covers common operational tasks for the Traefik microservices stack. All commands assume you are in the `traefik/` directory unless otherwise noted.

---

## Table of Contents

1. [Certificate Rotation](#certificate-rotation)
2. [Adding a New Service Behind Traefik](#adding-a-new-service-behind-traefik)
3. [Updating Traefik Version](#updating-traefik-version)
4. [Restoring from acme.json Backup](#restoring-from-acmejson-backup)

---

## Certificate Rotation

### Local Development (mkcert)

Certificates generated with `mkcert` expire after 3 months. Regenerate them before expiration.

**Steps:**

1. **Generate new certs:**
   ```bash
   mkcert -cert-file certs/dev.localhost.pem \
          -key-file certs/dev.localhost-key.pem \
          dev.localhost "*.dev.localhost" ::1
   ```

2. **Verify Traefik picks up the new cert:**
   ```bash
   docker compose logs traefik | grep -i "cert"
   ```

3. **Test by visiting the dashboard:**
   ```
   https://dev.localhost/dashboard/
   ```
   Check that the browser recognizes the new cert (no "untrusted" warnings).

**Troubleshooting:**
- If Traefik doesn't reload the cert, restart the container:
  ```bash
  docker compose restart traefik
  ```

### Production (Let's Encrypt)

Let's Encrypt certificates are automatically renewed by Traefik 30 days before expiration. No manual action is required.

**Verification:**

Check `letsencrypt/acme.json` for the renewal timestamp:
```bash
cat letsencrypt/acme.json | jq '.Certificates[0].Issued'
```

**Manual Renewal (if needed):**

1. Force renewal by temporarily disabling Traefik's cache:
   ```bash
   mv letsencrypt/acme.json letsencrypt/acme.json.backup
   docker compose restart traefik
   ```

2. Monitor the logs for ACME challenges:
   ```bash
   docker compose logs -f traefik | grep -i acme
   ```

3. Once renewed, restore the old file if the new one fails:
   ```bash
   mv letsencrypt/acme.json.backup letsencrypt/acme.json
   docker compose restart traefik
   ```

---

## Adding a New Service Behind Traefik

### Prerequisites

- Service is containerized and runnable with Docker
- Service exposes a port (e.g., `8080`)
- Service is accessible within the Docker network or on the host

### Steps

1. **Add service to `docker-compose.yml`:**

   ```yaml
   myapp:
     image: myapp:latest
     container_name: myapp
     ports:
       - "8080:8080"
     networks:
       - proxy
     labels:
       - "traefik.enable=true"
       - "traefik.http.routers.myapp.rule=Host(`myapp.${TRAEFIK_DASHBOARD_HOST}`)"
       - "traefik.http.routers.myapp.entrypoints=websecure"
       - "traefik.http.routers.myapp.tls.certresolver=${CERT_RESOLVER}"
       - "traefik.http.services.myapp.loadbalancer.server.port=8080"
   ```

2. **Start the service:**

   ```bash
   docker compose up -d myapp
   ```

3. **Verify Traefik detected the service:**

   ```bash
   docker compose logs traefik | grep -i myapp
   ```

4. **Test the route:**

   **Local development:**
   ```bash
   curl -k https://myapp.dev.localhost/
   ```

   **Production:**
   ```bash
   curl https://myapp.yourdomain.com/
   ```

### Troubleshooting

**Service not appearing in Traefik:**
- Check that `traefik.enable=true` is set
- Verify the service is running: `docker compose ps myapp`
- Check Traefik logs: `docker compose logs traefik`

**404 errors:**
- Verify the `Host()` rule matches your request
- Check that the service is responding on the port specified in `traefik.http.services.*.loadbalancer.server.port`
- Ensure the service is on the `proxy` network

**Cert errors:**
- Verify `CERT_RESOLVER` environment variable is set correctly
- Check `TRAEFIK_DASHBOARD_HOST` matches your domain
- Review Traefik logs for ACME errors

---

## Updating Traefik Version

Traefik updates are backward compatible within minor versions. Always test in a staging environment before updating production.

### Steps

1. **Check current version:**

   ```bash
   docker compose logs traefik | grep "Version"
   ```

2. **Update the image tag in `docker-compose.yml`:**

   Change:
   ```yaml
   image: traefik:v3.0.0
   ```
   To:
   ```yaml
   image: traefik:v3.1.0
   ```

3. **Pull the new image:**

   ```bash
   docker compose pull traefik
   ```

4. **Stop the current container:**

   ```bash
   docker compose stop traefik
   ```

5. **Start with the new image:**

   ```bash
   docker compose up -d traefik
   ```

6. **Monitor logs for startup errors:**

   ```bash
   docker compose logs -f traefik
   ```

7. **Verify all routes still work:**

   Test each service route (dashboard, main app, etc.)

### Rollback

If the update breaks services:

1. **Revert the image tag in `docker-compose.yml`**

2. **Restart:**

   ```bash
   docker compose pull traefik
   docker compose up -d traefik
   ```

3. **Verify routes are restored**

### Breaking Changes

Review the [Traefik changelog](https://github.com/traefik/traefik/releases) before updating major or minor versions for deprecations or config changes. Check especially:
- API changes
- Middleware renames
- TLS configuration updates
- Entrypoint behavior changes

---

## Restoring from acme.json Backup

The `letsencrypt/acme.json` file contains your Let's Encrypt private keys and certificates. Losing it requires reissuing all certificates. Keep regular backups.

### Backup Location

If you've set up automated backups (see `docs/production-hardening.md`), backups are stored off-host (S3, B2, secondary server, etc.).

### Restore Steps

1. **Stop Traefik:**

   ```bash
   docker compose stop traefik
   ```

2. **Download the backup:**

   **From S3:**
   ```bash
   aws s3 cp s3://your-bucket/traefik-backups/acme.json letsencrypt/acme.json
   ```

   **From B2:**
   ```bash
   b2 download-file-by-id b2-file-id letsencrypt/acme.json
   ```

   **From secondary server:**
   ```bash
   scp backup-server:/backups/acme.json letsencrypt/acme.json
   ```

3. **Verify permissions (must be readable by Traefik container):**

   ```bash
   chmod 600 letsencrypt/acme.json
   ```

4. **Restart Traefik:**

   ```bash
   docker compose up -d traefik
   ```

5. **Verify certificates are restored:**

   ```bash
   docker compose logs traefik | grep -i "certificate"
   cat letsencrypt/acme.json | jq '.Certificates | length'
   ```

6. **Test routes:**

   ```bash
   curl https://myapp.yourdomain.com/
   ```

### Emergency (No Backup)

If the backup is unavailable and `acme.json` was lost:

1. **Delete the corrupted file:**

   ```bash
   rm letsencrypt/acme.json
   ```

2. **Restart Traefik (it will create a new acme.json):**

   ```bash
   docker compose up -d traefik
   ```

3. **Traefik will request new certificates from Let's Encrypt.** This may take a few minutes and trigger multiple ACME challenges. Monitor logs:

   ```bash
   docker compose logs -f traefik | grep -i acme
   ```

4. **Once renewed, verify routes work and backup the new acme.json immediately:**

   ```bash
   cp letsencrypt/acme.json ~/backups/acme.json.$(date +%s)
   ```

**Costs of certificate reissue:**
- Potential brief downtime during challenge
- Rate limits: Let's Encrypt allows 50 cert issuances per domain per week
- Operational overhead and alerting

**Prevention:** Implement automated backups (see `docs/production-hardening.md`).

---

## Quick Reference

| Task | Command |
|------|---------|
| View Traefik logs | `docker compose logs -f traefik` |
| View all routes | `docker compose logs traefik \| grep -i router` |
| Check service health | `docker compose ps` |
| Reload Traefik config | `docker compose restart traefik` |
| Verify cert in acme.json | `jq '.Certificates[0]' letsencrypt/acme.json` |
| Test a route | `curl -k https://myapp.yourdomain.com/` |

---

## Support & Escalation

For issues not covered in this runbook:

1. Check `docs/production-hardening.md` for security-related troubleshooting
2. Review Traefik docs: https://doc.traefik.io/traefik/v3.0/
3. Check Traefik container logs for detailed error messages
4. Verify `.env` configuration matches your environment
