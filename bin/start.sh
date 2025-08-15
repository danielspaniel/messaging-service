#!/bin/bash

set -e

echo "Starting the messaging service..."
echo "Environment: ${ENV:-development}"

# Ensure the database is set up
echo "Setting up database..."
bundle exec rails db:create db:migrate 2>/dev/null || echo "Database already exists"

# Start the Rails server on port 8080
echo "Starting Rails server on port 8080..."
bundle exec rails server -p 8080 -b 0.0.0.0 