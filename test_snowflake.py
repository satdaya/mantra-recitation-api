#!/usr/bin/env python
"""Test Snowflake connection"""

from app.core.database import db
from app.core.config import settings

print('=== Snowflake Configuration ===')
print(f'Database: {settings.SNOWFLAKE_DATABASE}')
print(f'Schema: {settings.SNOWFLAKE_SCHEMA}')
print(f'Debug mode: {settings.DEBUG}')
print(f'Security validation: {settings.ENABLE_SECURITY_VALIDATION}')

print('\n=== Testing Connection ===')
try:
    conn = db.connect()
    cursor = conn.cursor()

    # Check current database/schema
    cursor.execute('SELECT CURRENT_DATABASE(), CURRENT_SCHEMA()')
    result = cursor.fetchone()
    print(f'✅ Connected successfully!')
    print(f'Current Database: {result[0]}')
    print(f'Current Schema: {result[1]}')

    # Explicitly use the database and schema
    print(f'\nSwitching to {settings.SNOWFLAKE_DATABASE}.{settings.SNOWFLAKE_SCHEMA}...')
    cursor.execute(f'USE DATABASE {settings.SNOWFLAKE_DATABASE}')
    cursor.execute(f'USE SCHEMA {settings.SNOWFLAKE_SCHEMA}')

    # Verify switch
    cursor.execute('SELECT CURRENT_DATABASE(), CURRENT_SCHEMA()')
    result = cursor.fetchone()
    print(f'Now using Database: {result[0]}, Schema: {result[1]}')

    # Test table access with fully qualified name
    cursor.execute(f'SELECT COUNT(*) FROM {settings.SNOWFLAKE_DATABASE}.{settings.SNOWFLAKE_SCHEMA}.recitations')
    count = cursor.fetchone()[0]
    print(f'\n🎉 Recitations in table: {count}')
    cursor.close()
except Exception as e:
    print(f'❌ Connection failed!')
    print(f'Error: {e}')
    import traceback
    traceback.print_exc()
