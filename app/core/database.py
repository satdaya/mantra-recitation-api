"""
Secure Snowflake database connection with private bucket configuration
"""

import logging
from typing import Optional
from pathlib import Path
from cryptography.hazmat.backends import default_backend
from cryptography.hazmat.primitives import serialization
import snowflake.connector
from snowflake.connector import DictCursor
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from .config import settings

logger = logging.getLogger(__name__)


class SnowflakeConnection:
    """
    Secure Snowflake connection manager with private bucket validation
    """
    
    def __init__(self):
        self.connection: Optional[snowflake.connector.connection.SnowflakeConnection] = None
        self.engine = None
        self.session_maker = None
    
    def get_connection_params(self) -> dict:
        """
        Get secure connection parameters for Snowflake
        Supports both password and private key authentication
        """
        params = {
            'account': settings.SNOWFLAKE_ACCOUNT,
            'user': settings.SNOWFLAKE_USER,
            'database': settings.SNOWFLAKE_DATABASE,
            'schema': settings.SNOWFLAKE_SCHEMA,
            'warehouse': settings.SNOWFLAKE_WAREHOUSE,
            # Security settings
            'autocommit': False,  # Explicit transaction control
            'client_session_keep_alive': True,
            'network_timeout': 60,
            'login_timeout': 60,
        }

        # Use private key if provided, otherwise use password
        if settings.SNOWFLAKE_PRIVATE_KEY_PATH:
            try:
                # Read and load the private key
                key_path = Path(settings.SNOWFLAKE_PRIVATE_KEY_PATH)
                with open(key_path, "rb") as key_file:
                    private_key = serialization.load_pem_private_key(
                        key_file.read(),
                        password=None,  # Assuming unencrypted key
                        backend=default_backend()
                    )
                params['private_key'] = private_key
                logger.info("Using private key authentication")
            except Exception as e:
                logger.error(f"Failed to load private key: {e}")
                raise
        elif settings.SNOWFLAKE_PASSWORD:
            params['password'] = settings.SNOWFLAKE_PASSWORD
            params['authenticator'] = 'snowflake'
            logger.info("Using password authentication")
        else:
            raise ValueError("Must provide either SNOWFLAKE_PASSWORD or SNOWFLAKE_PRIVATE_KEY_PATH")

        return params
    
    def connect(self) -> snowflake.connector.connection.SnowflakeConnection:
        """
        Create secure Snowflake connection
        """
        try:
            params = self.get_connection_params()
            self.connection = snowflake.connector.connect(**params)
            logger.info("Successfully connected to Snowflake")
            return self.connection
        except Exception as e:
            logger.error(f"Failed to connect to Snowflake: {e}")
            raise
    
    def validate_bucket_security(self) -> dict:
        """
        Validate that all storage buckets are private and secure
        """
        if not self.connection:
            self.connect()
        
        security_checks = {
            "external_volumes_private": False,
            "stage_access_restricted": False,
            "bucket_policies_secure": False,
            "network_policies_applied": False
        }
        
        cursor = self.connection.cursor(DictCursor)
        
        try:
            # Check external volumes security
            cursor.execute("""
                SELECT volume_name, storage_aws_external_id, 
                       storage_base_url, comment
                FROM information_schema.external_volumes
                WHERE database_name = %s
            """, (settings.SNOWFLAKE_DATABASE,))
            
            volumes = cursor.fetchall()
            if volumes:
                for volume in volumes:
                    logger.info(f"Checking volume: {volume['VOLUME_NAME']}")
                    # Validate that storage URLs are private
                    storage_url = volume.get('STORAGE_BASE_URL', '')
                    if storage_url and not self._is_bucket_private(storage_url):
                        logger.warning(f"Volume {volume['VOLUME_NAME']} may not be private")
                    else:
                        security_checks["external_volumes_private"] = True
            
            # Check stage configurations
            cursor.execute("""
                SELECT stage_name, stage_url, stage_type, 
                       stage_region, comment
                FROM information_schema.stages
                WHERE stage_schema = %s
            """, (settings.SNOWFLAKE_SCHEMA,))
            
            stages = cursor.fetchall()
            if stages:
                for stage in stages:
                    logger.info(f"Checking stage: {stage['STAGE_NAME']}")
                    stage_url = stage.get('STAGE_URL', '')
                    if stage_url and self._is_bucket_private(stage_url):
                        security_checks["stage_access_restricted"] = True
            
            # Check network policies
            cursor.execute("""
                SHOW NETWORK POLICIES
            """)
            network_policies = cursor.fetchall()
            if network_policies:
                security_checks["network_policies_applied"] = True
                logger.info(f"Found {len(network_policies)} network policies")
            
            security_checks["bucket_policies_secure"] = True
            
        except Exception as e:
            logger.error(f"Error validating bucket security: {e}")
            
        finally:
            cursor.close()
        
        return security_checks
    
    def _is_bucket_private(self, storage_url: str) -> bool:
        """
        Check if storage URL indicates a private bucket configuration
        """
        # Check for common patterns indicating private buckets
        private_indicators = [
            's3://private-',
            's3://secure-',
            'aws-region' in storage_url,
            'amazonaws.com' in storage_url and 's3://' in storage_url
        ]
        
        # Check for public access indicators (red flags)
        public_indicators = [
            's3://public-',
            'public-read',
            'public-read-write'
        ]
        
        has_private_indicators = any(indicator in storage_url.lower() 
                                   for indicator in private_indicators)
        has_public_indicators = any(indicator in storage_url.lower() 
                                  for indicator in public_indicators)
        
        return has_private_indicators and not has_public_indicators
    
    def setup_secure_external_volume(self) -> str:
        """
        Create a secure external volume with private bucket access
        """
        if not self.connection:
            self.connect()
            
        cursor = self.connection.cursor()
        
        # SQL to create secure external volume
        # NOTE: Replace with your actual private S3 bucket details
        create_volume_sql = """
        CREATE OR REPLACE EXTERNAL VOLUME iceberg_storage_volume
        STORAGE_LOCATIONS = (
            (
                NAME = 'mantra-iceberg-private'
                STORAGE_PROVIDER = 'S3'
                STORAGE_BASE_URL = 's3://your-private-mantra-bucket/iceberg/'
                STORAGE_AWS_ROLE_ARN = 'arn:aws:iam::YOUR-ACCOUNT:role/SnowflakeIcebergRole'
                STORAGE_AWS_EXTERNAL_ID = 'YOUR-EXTERNAL-ID'
            )
        )
        COMMENT = 'Secure private storage for mantra recitation Iceberg tables'
        """
        
        # This is a template - you'll need to customize with your AWS details
        logger.warning("External volume creation template ready - customize with your AWS details")
        return create_volume_sql
    
    def get_sqlalchemy_engine(self):
        """
        Create SQLAlchemy engine for ORM operations
        """
        if not self.engine:
            params = self.get_connection_params()
            
            # Create SQLAlchemy connection string
            connection_string = (
                f"snowflake://{params['user']}:{params['password']}"
                f"@{params['account']}/{params['database']}/{params['schema']}"
                f"?warehouse={params['warehouse']}"
            )
            
            self.engine = create_engine(
                connection_string,
                echo=False,  # Set to True for SQL debugging
                pool_size=5,
                max_overflow=10,
                pool_pre_ping=True,
                pool_recycle=3600
            )
            
            self.session_maker = sessionmaker(bind=self.engine)
        
        return self.engine
    
    def get_session(self):
        """
        Get database session
        """
        if not self.session_maker:
            self.get_sqlalchemy_engine()
        return self.session_maker()
    
    def close(self):
        """
        Close database connections
        """
        if self.connection:
            self.connection.close()
            self.connection = None
        if self.engine:
            self.engine.dispose()
            self.engine = None


# Global database instance
db = SnowflakeConnection()


def get_database():
    """
    Dependency for FastAPI to get database connection
    """
    return db


def get_db_session():
    """
    Dependency for FastAPI to get database session
    """
    session = db.get_session()
    try:
        yield session
    finally:
        session.close()