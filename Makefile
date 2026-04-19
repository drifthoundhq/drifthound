# Makefile for DriftHound

setup:
	@bundle install
	@bin/rails db:drop db:create db:migrate db:seed

prepare-test-db:
	@docker compose up -d
	@RAILS_ENV=test bin/rails db:create db:migrate

run-tests:
	@RAILS_ENV=test bin/rails test
	@RAILS_ENV=test bin/rails test:system

start:
	@bin/rails server

docker-db-setup:
	@docker compose up -d --build
	@docker compose exec app bin/rails db:drop db:create db:migrate
	@echo "Waiting for app to be ready..."
	@until docker compose exec app curl -sf http://localhost:3000/up > /dev/null 2>&1; do sleep 1; done
	@docker compose exec app bin/rails db:seed:notifications
	@echo "App is ready!"

docker-start:
	@@docker compose up --build -d

docker-token:
	@docker compose exec app bin/rails api_tokens:generate[my-ci-token]

docker-stop:
	@docker compose down

docker-destroy:
	@docker compose down -v