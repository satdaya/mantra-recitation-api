-- Optimal Iceberg Table Structure for Mantra Recitation App
-- Using Snowflake as Iceberg Catalog

-- Create database and schema
CREATE DATABASE IF NOT EXISTS MANTRA_TRACKER;
USE DATABASE MANTRA_TRACKER;
CREATE SCHEMA IF NOT EXISTS ICEBERG_TABLES;
USE SCHEMA ICEBERG_TABLES;

-- 1. MANTRAS TABLE (Dimension - Small, slow-changing)
CREATE OR REPLACE ICEBERG TABLE mantras (
    id STRING NOT NULL,
    name STRING NOT NULL,
    sanskrit STRING,
    gurmukhi STRING,
    translation STRING,
    category STRING,
    traditional_count INTEGER DEFAULT 108,
    audio_url STRING,
    source STRING DEFAULT 'user', -- 'core', 'user', 'pending'
    user_id STRING,
    submitted_by STRING,
    submitted_at TIMESTAMP_NTZ,
    created_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    updated_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
)
CATALOG = 'SNOWFLAKE'
EXTERNAL_VOLUME = 'iceberg_storage_volume'
BASE_LOCATION = 'mantras/'
-- No partitioning needed - small dimension table
;

-- 2. USERS TABLE (Dimension - Small)
CREATE OR REPLACE ICEBERG TABLE users (
    id STRING NOT NULL,
    email STRING UNIQUE,
    username STRING,
    full_name STRING,
    timezone STRING DEFAULT 'UTC',
    preferences JSON, -- Store user preferences as JSON
    created_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    updated_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
)
CATALOG = 'SNOWFLAKE'
EXTERNAL_VOLUME = 'iceberg_storage_volume'
BASE_LOCATION = 'users/'
;

-- 3. RECITATIONS TABLE (Fact - Large, frequent inserts)
-- CRITICAL: Partition by date for optimal performance
CREATE OR REPLACE ICEBERG TABLE recitations (
    id STRING NOT NULL,
    user_id STRING NOT NULL,
    mantra_name STRING NOT NULL,
    count INTEGER NOT NULL,
    duration_minutes INTEGER NOT NULL,
    recitation_timestamp TIMESTAMP_NTZ NOT NULL,
    notes STRING,
    created_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    updated_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    -- Derived columns for partitioning
    recitation_date DATE GENERATED ALWAYS AS (DATE(recitation_timestamp)),
    recitation_year INTEGER GENERATED ALWAYS AS (YEAR(recitation_timestamp)),
    recitation_month INTEGER GENERATED ALWAYS AS (MONTH(recitation_timestamp))
)
CATALOG = 'SNOWFLAKE'
EXTERNAL_VOLUME = 'iceberg_storage_volume'
BASE_LOCATION = 'recitations/'
-- OPTIMAL: Partition by date (year/month) for time-series queries
PARTITION BY (recitation_year, recitation_month)
;

-- 4. MATERIALIZED VIEWS for Analytics (Optional but Recommended)
-- Daily aggregations for fast dashboard queries
CREATE OR REPLACE DYNAMIC TABLE daily_stats
TARGET_LAG = '1 hour'
WAREHOUSE = 'COMPUTE_WH'
AS
SELECT 
    user_id,
    recitation_date,
    COUNT(*) as total_sessions,
    SUM(count) as total_recitations,
    SUM(duration_minutes) as total_duration_minutes,
    AVG(count) as avg_recitations_per_session,
    AVG(duration_minutes) as avg_duration_per_session,
    COUNT(DISTINCT mantra_name) as unique_mantras_practiced
FROM recitations
GROUP BY user_id, recitation_date;

-- Monthly trends
CREATE OR REPLACE DYNAMIC TABLE monthly_trends  
TARGET_LAG = '1 day'
WAREHOUSE = 'COMPUTE_WH'
AS
SELECT 
    user_id,
    recitation_year,
    recitation_month,
    COUNT(*) as sessions,
    SUM(count) as total_count,
    SUM(duration_minutes) as total_duration,
    COUNT(DISTINCT mantra_name) as unique_mantras,
    COUNT(DISTINCT recitation_date) as active_days
FROM recitations
GROUP BY user_id, recitation_year, recitation_month;

-- Performance Optimization
-- Create clustering keys on frequently filtered columns
ALTER ICEBERG TABLE recitations CLUSTER BY (user_id, recitation_date);
ALTER ICEBERG TABLE mantras CLUSTER BY (user_id, category);

-- Indexes for faster lookups (if supported)
-- CREATE INDEX idx_recitations_user_date ON recitations (user_id, recitation_date);
-- CREATE INDEX idx_mantras_name ON mantras (name, user_id);