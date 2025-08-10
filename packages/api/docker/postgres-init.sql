-- Initialize databases
-- This script runs when the postgres container starts for the first time

-- Connect to database and enable pg_cron
\c jeeves;
CREATE EXTENSION IF NOT EXISTS pg_cron;