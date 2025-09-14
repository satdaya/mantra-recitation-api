-- Compatible Snowflake Iceberg Setup for Mantra Recitation API
-- Run these commands as ACCOUNTADMIN in Snowflake

-- Use the ACCOUNTADMIN role
USE ROLE ACCOUNTADMIN;

-- Create or use existing database
USE DATABASE MANTRA_DB;

-- Create schema for Iceberg tables (drop if exists to avoid conflicts)
DROP SCHEMA IF EXISTS ICEBERG_TABLES;
CREATE SCHEMA ICEBERG_TABLES
  COMMENT = 'Schema containing Iceberg tables for Mantra app';

USE SCHEMA ICEBERG_TABLES;

-- Drop existing integration if it exists
DROP STORAGE INTEGRATION IF EXISTS mantra_s3_integration;

-- Create storage integration for S3 (using your Terraform-created bucket)
CREATE STORAGE INTEGRATION mantra_s3_integration
  TYPE = EXTERNAL_STAGE
  STORAGE_PROVIDER = 'S3'
  ENABLED = TRUE
  STORAGE_AWS_ROLE_ARN = 'arn:aws:iam::790357010268:role/mantra-app-snowflake-s3-role'
  STORAGE_ALLOWED_LOCATIONS = ('s3://mantra-app-dev-bucket/iceberg/')
  COMMENT = 'S3 integration for Iceberg tables in mantra app bucket';

-- Show the storage integration details (you'll need this for IAM trust policy)
DESC STORAGE INTEGRATION mantra_s3_integration;

-- Drop existing stage if it exists
DROP STAGE IF EXISTS iceberg_stage;

-- Create external stage for Iceberg data
CREATE STAGE iceberg_stage
  STORAGE_INTEGRATION = mantra_s3_integration
  URL = 's3://mantra-app-dev-bucket/iceberg/'
  COMMENT = 'Stage for Iceberg table data storage';

-- Grant storage integration usage to application role
GRANT USAGE ON INTEGRATION mantra_s3_integration TO ROLE MANTRA_APP_ROLE;

-- Grant stage usage to application role
GRANT USAGE ON STAGE iceberg_stage TO ROLE MANTRA_APP_ROLE;
GRANT READ ON STAGE iceberg_stage TO ROLE MANTRA_APP_ROLE;
GRANT WRITE ON STAGE iceberg_stage TO ROLE MANTRA_APP_ROLE;

-- Verify the setup
SHOW INTEGRATIONS;
SHOW STAGES;

-- Switch to application role to test permissions (this part will fail until IAM is set up)
-- USE ROLE MANTRA_APP_ROLE;
-- USE DATABASE MANTRA_DB;
-- USE SCHEMA ICEBERG_TABLES;