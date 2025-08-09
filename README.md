# Mantra Recitation API

FastAPI backend for the Mantra Recitation Tracker application.

## Features

- **Mantra Management**: CRUD operations for mantras with Sikh-focused categories
- **Recitation Logging**: Track mantra recitations with counts and duration
- **Analytics**: Daily and monthly statistics via Snowflake/Iceberg
- **Authentication**: User management with JWT tokens
- **Gurmukhi Support**: Full Unicode support for Gurmukhi script

## Setup

1. Create virtual environment:
```bash
python3 -m venv .venv
source .venv/bin/activate  # On Windows: .venv\Scripts\activate
```

2. Install dependencies:
```bash
pip install -r requirements.txt
```

3. Set up environment variables:
```bash
cp .env.example .env
# Edit .env with your Snowflake credentials
```

4. Run the application:
```bash
uvicorn app.main:app --reload
```

## API Documentation

Once running, visit:
- API docs: http://localhost:8000/docs
- ReDoc: http://localhost:8000/redoc

## Database Setup

Execute the SQL commands in `snowflake_iceberg_setup.sql` to set up your Snowflake/Iceberg tables.

## Architecture

- **FastAPI**: Modern Python web framework
- **Pydantic**: Data validation and serialization
- **Snowflake**: Data warehouse with Iceberg tables
- **SQLAlchemy**: Database ORM
- **Alembic**: Database migrations