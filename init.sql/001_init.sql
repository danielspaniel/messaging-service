-- Initialize messaging service database
-- This file is automatically run when the PostgreSQL container starts

-- Create additional database for testing if it doesn't exist
SELECT 'CREATE DATABASE messaging_service_test'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'messaging_service_test');

-- Set up any additional database configuration
-- ALTER DATABASE messaging_service SET timezone = 'UTC';
