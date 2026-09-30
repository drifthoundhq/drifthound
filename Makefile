# Makefile for DriftHound

# ── Local ─────────────────────────────────────────────────────────────────────

setup:
	@bundle install
	@bin/rails db:drop db:create db:migrate db:seed

setup-demo:
	@bundle install
	@bin/rails db:drop db:create db:migrate db:seed:demo

start:
	@bin/rails server

# ── Docker ────────────────────────────────────────────────────────────────────

docker-setup:
	@docker compose up -d --build postgres
	@echo "Waiting for postgres..."
	@until docker compose exec postgres pg_isready -U drifthound > /dev/null 2>&1; do sleep 1; done
	@docker compose run --rm app bin/rails db:drop db:create db:migrate db:seed
	@docker compose up -d app
	@echo "Waiting for app to be ready..."
	@until docker compose exec app curl -sf http://localhost:3000/up > /dev/null 2>&1; do sleep 1; done
	@echo "App is ready!"

docker-setup-demo:
	@docker compose up -d --build postgres
	@echo "Waiting for postgres..."
	@until docker compose exec postgres pg_isready -U drifthound > /dev/null 2>&1; do sleep 1; done
	@docker compose run --rm app bin/rails db:drop db:create db:migrate db:seed:demo
	@docker compose up -d app
	@echo "Waiting for app to be ready..."
	@until docker compose exec app curl -sf http://localhost:3000/up > /dev/null 2>&1; do sleep 1; done
	@echo "App is ready!"

docker-start:
	@docker compose up -d

docker-stop:
	@docker compose down

docker-destroy:
	@docker compose down -v

docker-token:
	@docker compose exec app bin/rails api_tokens:generate[my-ci-token]

# ── Testing ───────────────────────────────────────────────────────────────────

prepare-test-db:
	@docker compose up -d
	@RAILS_ENV=test bin/rails db:create db:migrate

run-tests:
	@RAILS_ENV=test bin/rails test
	@RAILS_ENV=test bin/rails test:system
