"""
Configuration settings using Pydantic Settings
"""

from typing import List, Optional
from pydantic import BaseSettings, AnyHttpUrl, validator


class Settings(BaseSettings):
    """Application settings"""
    
    # API Settings
    API_V1_STR: str = "/api/v1"
    SECRET_KEY: str = "your-super-secret-key-change-this-in-production"
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60 * 24 * 8  # 8 days
    
    # CORS Settings
    ALLOWED_ORIGINS: List[AnyHttpUrl] = []
    ALLOWED_HOSTS: List[str] = ["localhost", "127.0.0.1"]
    
    @validator("ALLOWED_ORIGINS", pre=True)
    def assemble_cors_origins(cls, v: str | List[str]) -> List[str] | str:
        if isinstance(v, str) and not v.startswith("["):
            return [i.strip() for i in v.split(",")]
        elif isinstance(v, (list, str)):
            return v
        raise ValueError(v)
    
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
    
    class Config:
        env_file = ".env"
        case_sensitive = True


# Create settings instance
settings = Settings()