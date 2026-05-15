ifeq ($(OS),Windows_NT)
    SHELL := powershell.exe
	.SHELLFLAGS := -NoProfile -Command
else
    SHELL := /bin/bash
endif

.PHONY: up down ps build setup superuser clean clean-data \
        up-traefik up-static up-shortener \
        down-traefik down-static down-shortener \
        restart restart-traefik restart-static restart-shortener \
        logs-traefik logs-static logs-shortener \
        help

SUPER_USER  ?= admin
SUPER_EMAIL ?= admin@example.com
SUPER_PASS  ?=

# Auto-discover all service .env.example files one level deep
SERVICE_ENV_EXAMPLES := $(wildcard */.env.example)
SERVICE_ENVS         := $(patsubst %.example,%,$(SERVICE_ENV_EXAMPLES))


# Start all services (traefik first — it owns the proxy network)
up: up-traefik up-static up-shortener

# Stop all services (dependents first, traefik last)
down: down-shortener down-static down-traefik

# ── Individual service targets ─────────────────────────────────────────────────

up-traefik:
	docker compose --env-file .env --project-name traefik -f traefik/docker-compose.yml up -d

up-static:
	docker compose --env-file .env --project-name static_site -f static_site/docker-compose.yml up -d

up-shortener:
	docker compose --env-file .env --project-name url_shortener -f url_shortener/docker-compose.yml up -d --build

down-traefik:
	docker compose --env-file .env --project-name traefik -f traefik/docker-compose.yml down

down-static:
	docker compose --env-file .env --project-name static_site -f static_site/docker-compose.yml down

down-shortener:
	docker compose --env-file .env --project-name url_shortener -f url_shortener/docker-compose.yml down

# ── Restart ────────────────────────────────────────────────────────────────────

restart: down up

restart-traefik: down-traefik up-traefik

restart-static: down-static up-static

restart-shortener: down-shortener up-shortener


# ── Setup ──────────────────────────────────────────────────────────────────────

setup: .env $(SERVICE_ENVS)

.env: .env.example
	cp $< $@ 
	@echo "[ok] Created $@ -- review before running"

%/.env: %/.env.example
	cp $< $@ 
	@echo "[ok] Created $@ -- review before running"

# ── Superuser ──────────────────────────────────────────────────────────────────

superuser:
ifeq ($(SUPER_PASS),)
	docker compose --env-file .env --project-name url_shortener -f url_shortener/docker-compose.yml exec \
		-e DJANGO_SUPERUSER_USERNAME=$(SUPER_USER) \
		-e DJANGO_SUPERUSER_EMAIL=$(SUPER_EMAIL) \
		app python manage.py createsuperuser
else
	docker compose --env-file .env --project-name url_shortener -f url_shortener/docker-compose.yml exec \
		-e DJANGO_SUPERUSER_USERNAME=$(SUPER_USER) \
		-e DJANGO_SUPERUSER_EMAIL=$(SUPER_EMAIL) \
		-e DJANGO_SUPERUSER_PASSWORD=$(SUPER_PASS) \
		app python manage.py createsuperuser --noinput
endif

# ── Clean ──────────────────────────────────────────────────────────────────────

# Remove containers, orphans, and locally built images — volumes are preserved
clean:
	docker compose --env-file .env --project-name url_shortener -f url_shortener/docker-compose.yml down --remove-orphans --rmi local
	docker compose --env-file .env --project-name static_site -f static_site/docker-compose.yml down --remove-orphans
	docker compose --env-file .env --project-name traefik -f traefik/docker-compose.yml down --remove-orphans

# Remove containers, orphans, and ALL named volumes — destroys the database
clean-data:
ifeq ($(OS),Windows_NT)
	@$$confirm = Read-Host 'WARNING: This deletes all volumes including the PostgreSQL database. Type yes to continue'; if ($$confirm -ne 'yes') { Write-Host 'Aborted.'; exit 1 }
else
	@read -p "WARNING: This deletes all volumes including the PostgreSQL database. Type 'yes' to continue: " confirm; if [ "$$confirm" != "yes" ]; then echo "Aborted."; exit 1; fi
endif
	docker compose --env-file .env --project-name url_shortener -f url_shortener/docker-compose.yml down -v --remove-orphans
	docker compose --env-file .env --project-name static_site -f static_site/docker-compose.yml down -v --remove-orphans
	docker compose --env-file .env --project-name traefik -f traefik/docker-compose.yml down -v --remove-orphans

# ── Build ──────────────────────────────────────────────────────────────────────

# Only url_shortener has a Dockerfile; traefik and static_site use upstream images
build:
	docker compose --env-file .env --project-name url_shortener -f url_shortener/docker-compose.yml build

# ── Status & logs ──────────────────────────────────────────────────────────────

ps:
	@echo "--- traefik ---"
	@docker compose --env-file .env --project-name traefik -f traefik/docker-compose.yml ps
	@echo "--- static_site ---"
	@docker compose --env-file .env --project-name static_site -f static_site/docker-compose.yml ps
	@echo "--- url_shortener ---"
	@docker compose --env-file .env --project-name url_shortener -f url_shortener/docker-compose.yml ps

logs-traefik:
	docker compose --env-file .env --project-name traefik -f traefik/docker-compose.yml logs -f

logs-static:
	docker compose --env-file .env --project-name static_site -f static_site/docker-compose.yml logs -f

logs-shortener:
	docker compose --env-file .env --project-name url_shortener -f url_shortener/docker-compose.yml logs -f

# ── Help ───────────────────────────────────────────────────────────────────────

help:
	@$(info Usage: make <target>)
	@$(info )
	@$(info   setup              Copy .env.example -> .env for each service missing one)
	@$(info   up                 Start all services)
	@$(info   down               Stop all services)
	@$(info   restart            Stop then start all services)
	@$(info   ps                 Show container status for all services)
	@$(info   build              Rebuild url_shortener image)
	@$(info )
	@$(info   up-traefik         Start traefik only)
	@$(info   up-static          Start static_site only)
	@$(info   up-shortener       Start url_shortener only)
	@$(info   down-traefik       Stop traefik only)
	@$(info   down-static        Stop static_site only)
	@$(info   down-shortener     Stop url_shortener only)
	@$(info   restart-traefik    Restart traefik only)
	@$(info   restart-static     Restart static_site only)
	@$(info   restart-shortener  Restart url_shortener only)
	@$(info   logs-traefik       Follow traefik logs)
	@$(info   logs-static        Follow static_site logs)
	@$(info   logs-shortener     Follow url_shortener logs)
	@$(info )
	@$(info   superuser          Create a Django superuser -- add SUPER_PASS=secret to skip prompts)
	@$(info )
	@$(info   clean              Remove containers and locally built images (volumes kept))
	@$(info   clean-data         Remove containers and ALL volumes -- destroys the database)
	@:
