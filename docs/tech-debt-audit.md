# Tech Debt Audit — Traefik Microservices Stack

**Updated:** 2026-05-17
**Scope:** traefik · static_site · url_shortener · root-level
**Method:** Priority = (Impact + Risk) × (6 − Effort)

---

## Resolved items

These were identified in the original 2026-04-30 audit and have since been addressed.

| Item | Resolution |
|---|---|
| No `.gitignore` covering secrets | Root `.gitignore` covers `traefik/certs/`, `traefik/letsencrypt/`, `dashboard-users.htpasswd`, and `**/.env` |
| Referenced docs do not exist | `docs/production-hardening.md` and `docs/automating-deployment-summary.md` created |
| No runbooks for common operations | `docs/runbook.md` created (cert rotation, add-a-service, Traefik update, acme.json restore) |
| Network comment says overlay, config uses bridge | Verified resolved |
| Root README stale (no Makefile, no static_site, no QR) | Updated 2026-05-14 |
| `url_shortener/SETUP.md` stale (wrong hostname, old dir name, QR in Next Steps) | Updated 2026-05-14 |
| `CLAUDE.md` references non-existent `entrypoint.sh` | Removed 2026-05-14 |
| `static_site` undocumented | `static_site/README.md` created 2026-05-14 |
| `ASSETS_URL` redundant env var | Derived from `DOMAIN` in `settings.py`; removed from `docker-compose.yml` 2026-05-14 |
| Django serving shortener and QR generator HTML | Migrated to static nginx container; Django now handles API, admin, redirects, and static assets only. Context processor, templates, partials bind-mount, and `STATICFILES_DIRS` removed 2026-05-17 |

---

## Open items

### 1. Source bind-mount has no dev/prod split — Priority 18

**Category:** Architecture · **Risk:** Medium

`url_shortener/docker-compose.yml` bind-mounts all source code into the running container (`./:/app`). In dev this gives live reloading; on a VPS it means the container reads from the local checkout rather than the baked Dockerfile image layer. The `COPY . .` step in the Dockerfile is bypassed in any deployment that uses this compose file as-is.

**Fix:** Add a `docker-compose.prod.yml` override that removes the bind-mount volume, so production containers run the baked image.

---

### 2. Watchtower not integrated — Priority 16

**Category:** Infrastructure

Without Watchtower, image updates require manual SSH + `docker compose pull && docker compose up -d` per service. For a 1–3 person team this compounds fast across multiple microservices.

**Fix:** Add a `watchtower` service to the traefik or a dedicated compose file, scoped to labelled containers only (`--label-enable`).

---

### 3. No container health check on Traefik — Priority 15

**Category:** Infrastructure

The `traefik` service has no `healthcheck` block. Docker cannot distinguish a hung process from a healthy one. Traefik v3 exposes a native ping endpoint.

**Fix:**
```yaml
healthcheck:
  test: ["CMD", "traefik", "healthcheck", "--ping"]
  interval: 30s
  timeout: 5s
  retries: 3
```
Enable the ping endpoint with `--ping` in the command block.

---

### 4. Dashboard exposed with only basic auth — Priority 12

**Category:** Architecture · Infrastructure

The Traefik dashboard is reachable from the public internet with no rate limiting or IP restriction. Brute-force against basic auth is unconstrained.

**Fix:** Add an `ipallowlist` middleware restricting dashboard access to known operator IPs. See `docs/production-hardening.md` for the label syntax.

---

### 5. No backup strategy for `acme.json` — Priority 12

**Category:** Infrastructure

Let's Encrypt rate-limits issuance to 5 certificates per registered domain per week. If `acme.json` is lost, recovery takes days. See `docs/runbook.md` for the restore procedure — but prevention (an automated off-host backup) hasn't been set up.

**Fix:** Schedule a nightly cron on the VPS copying `acme.json` to off-host storage (S3, B2, or secondary server).

---

### 6. Docker socket mounted directly — Priority 10

**Category:** Architecture

`/var/run/docker.sock` is mounted read-only, which limits write access. However, read access still exposes container metadata, environment variables, and labels across the entire Docker host.

**Fix:** Insert `tecnativa/docker-socket-proxy` between Traefik and the socket, exposing only the `CONTAINERS` and `NETWORKS` APIs Traefik needs.

---

### 7. CI/CD pipeline not implemented — Priority 8

**Category:** Infrastructure

No automated pipeline exists for building and publishing Docker images. Manual image builds mean every deploy carries human-error risk.

**Fix:** Implement a `build-and-push.yml` GitHub Actions workflow triggered on semantic version tags, publishing to GHCR. Wire Watchtower to pick up new tags automatically.

---

### 8. Prometheus metrics enabled, no scraper configured — Priority 8

**Category:** Infrastructure

`--metrics.prometheus=true` is set in the Traefik command block, but nothing is scraping the endpoint. The data is generated and discarded.

**Fix:** Either add a lightweight Prometheus + Grafana compose file, or remove the `--metrics.prometheus` flag until monitoring is actually wired up.

---

## Phased remediation

### Phase 1 — Next PR (low-effort, high-impact)
- Add Traefik health check *(30 min)*
- Set up `acme.json` nightly backup cron on VPS *(45 min)*

### Phase 2 — After CI/CD is planned
- Integrate Watchtower
- Add IP allowlist or rate-limit middleware to dashboard router
- Create `docker-compose.prod.yml` removing the source bind-mount

### Phase 3 — When deployment pipeline exists
- Implement GitHub Actions build-and-push
- Add Docker socket proxy (higher breakage risk — safer with a pipeline to push fixes)
- Add Prometheus scraper or remove the flag
