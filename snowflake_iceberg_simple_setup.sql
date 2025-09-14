-- Simplified Snowflake Iceberg Setup for Mantra Recitation API
-- Run these commands as ACCOUNTADMIN in Snowflake

-- Use the ACCOUNTADMIN role
USE ROLE ACCOUNTADMIN;

-- Create or use existing database
USE DATABASE MANTRA_DB;

-- Create schema for Iceberg tables if it doesn't exist
CREATE SCHEMA IF NOT EXISTS ICEBERG_TABLES
  COMMENT = 'Schema containing Iceberg tables for Mantra app';

USE SCHEMA ICEBERG_TABLES;

-- Create storage integration for S3 (using your Terraform-created bucket)
CREATE STORAGE INTEGRATION IF NOT EXISTS mantra_s3_integration
  TYPE = EXTERNAL_STAGE
  STORAGE_PROVIDER = 'S3'
  ENABLED = TRUE
  STORAGE_AWS_ROLE_ARN = 'arn:aws:iam::790357010268:role/mantra-app-snowflake-s3-role'
  STORAGE_ALLOWED_LOCATIONS = ('s3://mantra-app-dev-bucket/iceberg/')
  COMMENT = 'S3 integration for Iceberg tables in mantra app bucket';

-- Show the storage integration details (you'll need this for IAM trust policy)
DESC STORAGE INTEGRATION mantra_s3_integration;

-- Create external stage for Iceberg data
CREATE STAGE IF NOT EXISTS iceberg_stage
  STORAGE_INTEGRATION = mantra_s3_integration
  URL = 's3://mantra-app-dev-bucket/iceberg/'
  COMMENT = 'Stage for Iceberg table data storage';

-- Grant storage integration usage to application role
GRANT USAGE ON INTEGRATION mantra_s3_integration TO ROLE MANTRA_APP_ROLE;

-- Grant stage usage to application role
GRANT USAGE ON STAGE iceberg_stage TO ROLE MANTRA_APP_ROLE;
GRANT READ ON STAGE iceberg_stage TO ROLE MANTRA_APP_ROLE;
GRANT WRITE ON STAGE iceberg_stage TO ROLE MANTRA_APP_ROLE;

-- Switch to application role to test permissions
USE ROLE MANTRA_APP_ROLE;
USE DATABASE MANTRA_DB;
USE SCHEMA ICEBERG_TABLES;

-- Test creating a simple Iceberg table (without catalog - using direct approach)
CREATE OR REPLACE ICEBERG TABLE mantras_iceberg (
    mantra_id STRING,
    name STRING,
    category STRING,
    text STRING,
    language STRING,
    created_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    updated_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
)
EXTERNAL_VOLUME = 'iceberg_stage'
CATALOG = 'SNOWFLAKE'
BASE_LOCATION = 'mantras/';

-- Test creating recitations table
CREATE OR REPLACE ICEBERG TABLE recitations_iceberg (
    recitation_id STRING,
    mantra_id STRING,
    user_id STRING,
    count INTEGER,
    duration_minutes INTEGER,
    recited_at TIMESTAMP_NTZ,
    notes STRING,
    created_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
)
EXTERNAL_VOLUME = 'iceberg_stage'
CATALOG = 'SNOWFLAKE'
BASE_LOCATION = 'recitations/';

-- Test inserting sample data
INSERT INTO mantras_iceberg (mantra_id, name, category, text, language)
VALUES 
    ('m1', 'Mool Mantra', 'Fundamental', 'Ik Onkar Sat Nam Karta Purakh...', 'Gurmukhi'),
    ('m2', 'Waheguru', 'Simran', 'Waheguru', 'Gurmukhi');

-- Test querying
SELECT * FROM mantras_iceberg;

-- Show table information
DESCRIBE TABLE mantras_iceberg;
SHOW TERSE TABLES LIKE '%iceberg%';

-- Verify Iceberg metadata
SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_TYPE = 'ICEBERG' AND TABLE_SCHEMA = 'ICEBERG_TABLES';