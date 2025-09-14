-- Snowflake Iceberg Catalog Setup for Mantra Recitation API
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
  STORAGE_AWS_ROLE_ARN = 'arn:aws:iam::790357010268:role/snowflake-s3-role'  -- You'll need to create this role
  STORAGE_ALLOWED_LOCATIONS = ('s3://mantra-app-dev-bucket/iceberg/')
  COMMENT = 'S3 integration for Iceberg tables in mantra app bucket';

-- Show the storage integration details (you'll need this for IAM trust policy)
DESC STORAGE INTEGRATION mantra_s3_integration;

-- Create Iceberg catalog
CREATE CATALOG IF NOT EXISTS mantra_iceberg_catalog
  CATALOG_SOURCE = 'SNOWFLAKE'
  TABLE_FORMAT = 'ICEBERG'
  COMMENT = 'Iceberg catalog for Mantra Recitation API tables';

-- Grant usage on catalog to your application role
GRANT USAGE ON CATALOG mantra_iceberg_catalog TO ROLE MANTRA_APP_ROLE;
GRANT CREATE TABLE ON CATALOG mantra_iceberg_catalog TO ROLE MANTRA_APP_ROLE;
GRANT CREATE SCHEMA ON CATALOG mantra_iceberg_catalog TO ROLE MANTRA_APP_ROLE;

-- Grant storage integration usage to application role
GRANT USAGE ON INTEGRATION mantra_s3_integration TO ROLE MANTRA_APP_ROLE;

-- Create external stage for Iceberg data
CREATE STAGE IF NOT EXISTS iceberg_stage
  STORAGE_INTEGRATION = mantra_s3_integration
  URL = 's3://mantra-app-dev-bucket/iceberg/'
  COMMENT = 'Stage for Iceberg table data storage';

-- Grant stage usage to application role
GRANT USAGE ON STAGE iceberg_stage TO ROLE MANTRA_APP_ROLE;
GRANT READ ON STAGE iceberg_stage TO ROLE MANTRA_APP_ROLE;
GRANT WRITE ON STAGE iceberg_stage TO ROLE MANTRA_APP_ROLE;

-- Verify the setup
SHOW CATALOGS;
SHOW INTEGRATIONS;
SHOW STAGES;

-- Switch to application role to test permissions
USE ROLE MANTRA_APP_ROLE;
USE DATABASE MANTRA_DB;
USE SCHEMA ICEBERG_TABLES;

-- Test creating a simple Iceberg table
CREATE OR REPLACE ICEBERG TABLE mantras_iceberg (
    mantra_id STRING,
    name STRING,
    category STRING,
    text STRING,
    language STRING,
    created_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    updated_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
)
CATALOG = 'mantra_iceberg_catalog'
EXTERNAL_VOLUME = 'iceberg_stage'
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
CATALOG = 'mantra_iceberg_catalog'
EXTERNAL_VOLUME = 'iceberg_stage'
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