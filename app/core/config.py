"""
Configuration settings using Pydantic Settings
"""

import json
import boto3
from typing import List, Optional
from pydantic import AnyHttpUrl, field_validator
from pydantic_settings import BaseSettings
from functools import lru_cache


class Settings(BaseSettings):
    """Application settings"""
    
    # API Settings
    API_V1_STR: str = "/api/v1"
    SECRET_KEY: str = "your-super-secret-key-change-this-in-production"
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60 * 24 * 8  # 8 days
    
    # CORS Settings - simplified to avoid parsing issues
    ALLOWED_ORIGINS_STR: str = "http://localhost:3000,http://localhost:5173"
    ALLOWED_HOSTS: List[str] = ["localhost", "127.0.0.1", "*"]
    
    @property
    def ALLOWED_ORIGINS(self) -> List[str]:
        """Parse ALLOWED_ORIGINS from string"""
        if not self.ALLOWED_ORIGINS_STR:
            return []
        return [origin.strip() for origin in self.ALLOWED_ORIGINS_STR.split(",")]
    
    # Database Settings - Snowflake (Secure Configuration)
    SNOWFLAKE_ACCOUNT: str = ""
    SNOWFLAKE_USER: str = ""
    SNOWFLAKE_PASSWORD: str = ""
    SNOWFLAKE_DATABASE: str = "MANTRA_TRACKER"
    SNOWFLAKE_SCHEMA: str = "ICEBERG_TABLES"  # Updated to match SQL setup
    SNOWFLAKE_WAREHOUSE: str = "COMPUTE_WH"
    SNOWFLAKE_ROLE: Optional[str] = None  # Optional: specify role for least privilege
    
    # Security Settings
    ENABLE_SECURITY_VALIDATION: bool = True
    REQUIRE_SECURE_BUCKETS: bool = True
    MAX_CONNECTION_RETRIES: int = 3
    CONNECTION_TIMEOUT_SECONDS: int = 60
    
    # Storage Security
    STORAGE_ENCRYPTION_REQUIRED: bool = True
    BLOCK_PUBLIC_BUCKET_ACCESS: bool = True
    
    # Optional: Airtable Integration
    AIRTABLE_BASE_ID: Optional[str] = None
    AIRTABLE_API_KEY: Optional[str] = None
    
    # Development Settings
    DEBUG: bool = False
    LOG_LEVEL: str = "INFO"
    
    # AWS Settings
    AWS_REGION: str = "us-west-2"
    
    class Config:
        env_file = ".env"
        case_sensitive = True


@lru_cache()
def get_secret(secret_name: str) -> dict:
    """Retrieve secret from AWS Secrets Manager"""
    try:
        client = boto3.client('secretsmanager')
        response = client.get_secret_value(SecretId=secret_name)
        return json.loads(response['SecretString'])
    except Exception as e:
        print(f"Error retrieving secret {secret_name}: {e}")
        return {}


@lru_cache()
def get_settings() -> Settings:
    """Get application settings with secrets from AWS Secrets Manager"""
    settings = Settings()
    
    # Skip AWS Secrets Manager in development mode
    if settings.DEBUG or not settings.ENABLE_SECURITY_VALIDATION:
        print("DEBUG: Skipping AWS Secrets Manager in development mode")
        return settings
    
    # Load AWS credentials from Secrets Manager
    aws_secret_name = "mantra-app-dev-aws-credentials"
    aws_creds = get_secret(aws_secret_name)
    
    # Load Snowflake credentials from Secrets Manager
    snowflake_secret_name = "mantra-app-dev-snowflake-credentials"
    snowflake_creds = get_secret(snowflake_secret_name)
    
    # Update settings with retrieved credentials
    if snowflake_creds:
        settings.SNOWFLAKE_ACCOUNT = snowflake_creds.get('SNOWFLAKE_ACCOUNT', settings.SNOWFLAKE_ACCOUNT)
        settings.SNOWFLAKE_USER = snowflake_creds.get('SNOWFLAKE_USERNAME', settings.SNOWFLAKE_USER)
        settings.SNOWFLAKE_PASSWORD = snowflake_creds.get('SNOWFLAKE_PASSWORD', settings.SNOWFLAKE_PASSWORD)
        settings.SNOWFLAKE_DATABASE = snowflake_creds.get('SNOWFLAKE_DATABASE', settings.SNOWFLAKE_DATABASE)
        settings.SNOWFLAKE_SCHEMA = snowflake_creds.get('SNOWFLAKE_SCHEMA', settings.SNOWFLAKE_SCHEMA)
        settings.SNOWFLAKE_WAREHOUSE = snowflake_creds.get('SNOWFLAKE_WAREHOUSE', settings.SNOWFLAKE_WAREHOUSE)
    
    return settings


# Create settings instance (use the function to get secrets)
settings = get_settings()