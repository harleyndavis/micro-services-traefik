.PHONY: up down ps build setup superuser clean clean-data \
        up-traefik up-static up-shortener \
        down-traefik down-static down-shortener \
        restart restart-traefik restart-static restart-shortener \
        logs-traefik logs-static logs-shortener \
        help

SUPER_USER  ?= admin
SUPER_EMAIL ?= admin@example.com
SUPER_PASS  ?=

# Start all services (traefik first — it owns the proxy network)
up: up-traefik up-static up-shortener

# Stop all services (dependents first, traefik last)
down: down-shortener down-static down-traefik

# ── Individual service targets ─────────────────────────────────────────────────

up-traefik:
	docker compose --project-directory traefik -f traefik/docker-compose.yml up -d

up-static:
	docker compose --project-directory static_site -f static_site/docker-compose.yml up -d

up-shortener:
	docker compose --project-directory url_shortener -f url_shortener/docker-compose.yml up -d --build

down-traefik:
	docker compose --project-directory traefik -f traefik/docker-compose.yml down

down-static:
	docker compose --project-directory static_site -f static_site/docker-compose.yml down

down-shortener:
	docker compose --project-directory url_shortener -f url_shortener/docker-compose.yml down

# ── Restart ────────────────────────────────────────────────────────────────────

restart: down up

restart-traefik: down-traefik up-traefik

restart-static: down-static up-static

restart-shortener: down-shortener up-shortener

# ── Setup ──────────────────────────────────────────────────────────────────────

setup:
	@for dir in traefik static_site url_shortener; do \
		if [ -f $$dir/.env ]; then \
			echo "✓ $$dir/.env already exists"; \
		elif [ -f $$dir/.env.example ]; then \
			cp $$dir/.env.example $$dir/.env; \
			echo "✓ $$dir/.env created from .env.example — review before running"; \
		else \
			echo "✗ $$dir has no .env or .env.example"; \
		fi; \
	done

# ── Superuser ──────────────────────────────────────────────────────────────────

superuser:
	@if [ -n "$(SUPER_PASS)" ]; then \
		docker compose --project-directory url_shortener -f url_shortener/docker-compose.yml exec \
			-e DJANGO_SUPERUSER_USERNAME=$(SUPER_USER) \
			-e DJANGO_SUPERUSER_EMAIL=$(SUPER_EMAIL) \
			-e DJANGO_SUPERUSER_PASSWORD=$(SUPER_PASS) \
			app python manage.py createsuperuser --noinput; \
	else \
		docker compose --project-directory url_shortener -f url_shortener/docker-compose.yml exec \
			-e DJANGO_SUPERUSER_USERNAME=$(SUPER_USER) \
			-e DJANGO_SUPERUSER_EMAIL=$(SUPER_EMAIL) \
			app python manage.py createsuperuser; \
	fi

# ── Clean ──────────────────────────────────────────────────────────────────────

# Remove containers, orphans, and locally built images — volumes are preserved
clean:
	docker compose --project-directory url_shortener -f url_shortener/docker-compose.yml down --remove-orphans --rmi local
	docker compose --project-directory static_site -f static_site/docker-compose.yml down --remove-orphans
	docker compose --project-directory traefik -f traefik/docker-compose.yml down --remove-orphans

# Remove containers, orphans, and ALL named volumes — destroys the database
clean-data:
	@read -p "WARNING: This deletes all volumes including the PostgreSQL database. Type 'yes' to continue: " confirm; \
	if [ "$$confirm" != "yes" ]; then echo "Aborted."; exit 1; fi; \
	docker compose --project-directory url_shortener -f url_shortener/docker-compose.yml down -v --remove-orphans; \
	docker compose --project-directory static_site -f static_site/docker-compose.yml down -v --remove-orphans; \
	docker compose --project-directory traefik -f traefik/docker-compose.yml down -v --remove-orphans

# ── Build ──────────────────────────────────────────────────────────────────────

# Only url_shortener has a Dockerfile; traefik and static_site use upstream images
build:
	docker compose --project-directory url_shortener -f url_shortener/docker-compose.yml build

# ── Status & logs ──────────────────────────────────────────────────────────────

ps:
	@echo "--- traefik ---"
	@docker compose --project-directory traefik -f traefik/docker-compose.yml ps
	@echo "--- static_site ---"
	@docker compose --project-directory static_site -f static_site/docker-compose.yml ps
	@echo "--- url_shortener ---"
	@docker compose --project-directory url_shortener -f url_shortener/docker-compose.yml ps

logs-traefik:
	docker compose --project-directory traefik -f traefik/docker-compose.yml logs -f

logs-static:
	docker compose --project-directory static_site -f static_site/docker-compose.yml logs -f

logs-shortener:
	docker compose --project-directory url_shortener -f url_shortener/docker-compose.yml logs -f

# ── Help ───────────────────────────────────────────────────────────────────────

help:
	@echo "Usage: make <target>"
	@echo ""
	@echo "  setup            Copy .env.example → .env for any service missing one"
	@echo "  up               Start all services"
	@echo "  down             Stop all services"
	@echo "  restart          Stop then start all services"
	@echo "  ps               Show container status for all services"
	@echo "  build            Rebuild url_shortener image"
	@echo ""
	@echo "  up-traefik       Start traefik only"
	@echo "  up-static        Start static_site only"
	@echo "  up-shortener     Start url_shortener only"
	@echo ""
	@echo "  down-traefik     Stop traefik only"
	@echo "  down-static      Stop static_site only"
	@echo "  down-shortener   Stop url_shortener only"
	@echo ""
	@echo "  restart-traefik   Restart traefik only"
	@echo "  restart-static    Restart static_site only"
	@echo "  restart-shortener Restart url_shortener only"
	@echo ""
	@echo "  logs-traefik     Follow traefik logs"
	@echo "  logs-static      Follow static_site logs"
	@echo "  logs-shortener   Follow url_shortener logs"
	@echo ""
	@echo "  superuser        Create a Django superuser (app must be running)"
	@echo "    Non-interactive:  make superuser SUPER_USER=admin SUPER_EMAIL=you@example.com SUPER_PASS=secret"
	@echo "    Interactive:      make superuser SUPER_USER=admin  (prompts for email/password)"
	@echo ""
	@echo "  clean            Remove containers and locally built images (volumes kept)"
	@echo "  clean-data       Remove containers and ALL volumes — destroys the database"
