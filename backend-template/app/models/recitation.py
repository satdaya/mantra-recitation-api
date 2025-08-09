"""
Recitation data models
"""

from datetime import datetime
from typing import Optional
from pydantic import BaseModel, Field


class RecitationBase(BaseModel):
    """Base recitation model"""
    mantra_name: str = Field(..., min_length=1, max_length=200)
    count: int = Field(..., ge=1)
    duration_minutes: int = Field(..., ge=1)
    recitation_timestamp: datetime
    notes: Optional[str] = Field(None, max_length=1000)


class RecitationCreate(RecitationBase):
    """Schema for creating a new recitation"""
    pass


class RecitationUpdate(BaseModel):
    """Schema for updating a recitation"""
    mantra_name: Optional[str] = Field(None, min_length=1, max_length=200)
    count: Optional[int] = Field(None, ge=1)
    duration_minutes: Optional[int] = Field(None, ge=1)
    recitation_timestamp: Optional[datetime] = None
    notes: Optional[str] = Field(None, max_length=1000)


class Recitation(RecitationBase):
    """Full recitation model with database fields"""
    id: str
    user_id: str
    created_at: datetime
    updated_at: datetime
    
    class Config:
        from_attributes = True


class RecitationStats(BaseModel):
    """Statistics model matching your React frontend"""
    total_recitations: int
    total_count: int
    total_duration: int
    average_count: int
    average_duration: int
    most_recited_mantra: str


class DailyStats(BaseModel):
    """Daily statistics model"""
    date: str  # YYYY-MM-DD format
    count: int
    duration: int
    recitations: int