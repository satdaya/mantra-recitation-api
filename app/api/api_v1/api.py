"""
API v1 router - Recitation endpoints with Snowflake persistence
"""

from datetime import datetime
from typing import List, Optional
from fastapi import APIRouter, HTTPException, Query

from app.models.recitation import (
    RecitationCreate,
    RecitationUpdate,
    Recitation
)
from app.services.recitation_service import get_recitation_service

api_router = APIRouter()

# Temporary: hardcoded user_id until auth is implemented
DEFAULT_USER_ID = "default-user"


@api_router.get("/mantras")
async def get_mantras():
    """Get all mantras (placeholder - mantras are in Google Sheet)"""
    return {
        "message": "Mantras are managed in Google Sheet",
        "data": []
    }


@api_router.post("/recitations", response_model=Recitation)
async def create_recitation(recitation: RecitationCreate):
    """
    Create a new recitation record.

    This endpoint persists the recitation to Snowflake Iceberg tables.
    Call this from the frontend on every save action.
    """
    try:
        service = get_recitation_service()
        created = service.create_recitation(recitation, user_id=DEFAULT_USER_ID)
        return created
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to create recitation: {str(e)}")


@api_router.get("/recitations", response_model=List[Recitation])
async def get_recitations(
    start_date: Optional[datetime] = Query(None, description="Filter by start date"),
    end_date: Optional[datetime] = Query(None, description="Filter by end date"),
    limit: int = Query(100, ge=1, le=1000, description="Max records to return"),
    offset: int = Query(0, ge=0, description="Records to skip")
):
    """
    Get all recitations for the current user.

    Supports optional date range filtering and pagination.
    """
    try:
        service = get_recitation_service()
        recitations = service.get_recitations(
            user_id=DEFAULT_USER_ID,
            start_date=start_date,
            end_date=end_date,
            limit=limit,
            offset=offset
        )
        return recitations
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to fetch recitations: {str(e)}")


@api_router.get("/recitations/{recitation_id}", response_model=Recitation)
async def get_recitation(recitation_id: str):
    """
    Get a single recitation by ID.
    """
    try:
        service = get_recitation_service()
        recitation = service.get_recitation_by_id(recitation_id, user_id=DEFAULT_USER_ID)

        if not recitation:
            raise HTTPException(status_code=404, detail="Recitation not found")

        return recitation
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to fetch recitation: {str(e)}")


@api_router.put("/recitations/{recitation_id}", response_model=Recitation)
async def update_recitation(recitation_id: str, update_data: RecitationUpdate):
    """
    Update an existing recitation.
    """
    try:
        service = get_recitation_service()

        # Check if recitation exists
        existing = service.get_recitation_by_id(recitation_id, user_id=DEFAULT_USER_ID)
        if not existing:
            raise HTTPException(status_code=404, detail="Recitation not found")

        updated = service.update_recitation(
            recitation_id=recitation_id,
            user_id=DEFAULT_USER_ID,
            update_data=update_data
        )
        return updated
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to update recitation: {str(e)}")


@api_router.delete("/recitations/{recitation_id}")
async def delete_recitation(recitation_id: str):
    """
    Delete a recitation.
    """
    try:
        service = get_recitation_service()
        deleted = service.delete_recitation(recitation_id, user_id=DEFAULT_USER_ID)

        if not deleted:
            raise HTTPException(status_code=404, detail="Recitation not found")

        return {"message": "Recitation deleted successfully", "id": recitation_id}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to delete recitation: {str(e)}")
