FROM ruby:3.4.2-alpine

# Install system dependencies
RUN apk add --no-cache \
    build-base \
    postgresql-dev \
    yaml-dev \
    tzdata \
    curl \
    bash

# Set working directory
WORKDIR /app

# Copy Gemfile and Gemfile.lock
COPY Gemfile Gemfile.lock ./

# Install gems
RUN bundle install --jobs 4 --retry 3

# Copy application code
COPY . .

# Create necessary directories
RUN mkdir -p tmp/pids

# Expose port
EXPOSE 8080

# Start command
CMD ["./bin/start.sh"]
