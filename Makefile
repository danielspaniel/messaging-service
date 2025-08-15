.PHONY: setup run test integration-test clean help db-up db-down db-logs db-shell

help:
	@echo "Available commands:"
	@echo "  setup           - Build and start all services (app + database)"
	@echo "  run             - Run the full application stack"
	@echo "  test            - Run Rails tests in Docker container"
	@echo "  integration-test - Run HTTP integration tests against running services"
	@echo "  clean           - Stop and remove all containers and volumes"
	@echo "  db-up           - Start only the PostgreSQL database"
	@echo "  db-down         - Stop the PostgreSQL database"
	@echo "  db-logs         - Show database logs"
	@echo "  db-shell        - Connect to the database shell"
	@echo "  help            - Show this help message"

setup:
	@echo "Setting up the project..."
	@echo "Building and starting services..."
	@docker-compose up -d --build
	@echo "Waiting for services to be ready..."
	@sleep 10
	@echo "Setup complete! App running at http://localhost:8080"

run:
	@echo "Starting the messaging service..."
	@docker-compose up --build

test:
	@echo "Running Rails tests in Docker..."
	@docker-compose run --rm app bin/rails test

clean:
	@echo "Cleaning up..."
	@echo "Stopping and removing containers..."
	@docker-compose down -v
	@echo "Removing any temporary files..."
	@rm -rf *.log *.tmp

db-up:
	@echo "Starting PostgreSQL database..."
	@docker-compose up -d

db-down:
	@echo "Stopping PostgreSQL database..."
	@docker-compose down

db-logs:
	@echo "Showing database logs..."
	@docker-compose logs -f postgres

db-shell:
	@echo "Connecting to database shell..."
	@docker-compose exec postgres psql -U messaging_user -d messaging_service