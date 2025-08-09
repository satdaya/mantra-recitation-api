"""
Mantra data models matching your React frontend types
"""

from datetime import datetime
from typing import Optional
from pydantic import BaseModel, Field
from enum import Enum


class MantraSource(str, Enum):
    """Source of the mantra"""
    CORE = "core"
    USER = "user"
    PENDING = "pending"


class MantraCategory(str, Enum):
    """Mantra categories - Sikh focused"""
    DAILY_BANIS = "Daily Banis"
    CORE_MANTRAS = "Core Mantras"
    PAUREES = "Paurees"
    SIMRAN = "Simran"
    DEVOTION = "Devotion"
    WISDOM = "Wisdom"
    COMPASSION = "Compassion"
    PEACE = "Peace"
    HEALING = "Healing"
    PROTECTION = "Protection"
    PROSPERITY = "Prosperity"
    SELF_REALIZATION = "Self-realization"
    OTHER = "Other"


class MantraBase(BaseModel):
    """Base mantra model"""
    name: str = Field(..., min_length=1, max_length=200)
    sanskrit: Optional[str] = Field(None, max_length=1000)
    gurmukhi: Optional[str] = Field(None, max_length=1000)
    translation: Optional[str] = Field(None, max_length=1000)
    category: Optional[MantraCategory] = None
    traditional_count: int = Field(108, ge=1)
    audio_url: Optional[str] = Field(None, max_length=500)
    submitted_by: Optional[str] = Field(None, max_length=100)


class MantraCreate(MantraBase):
    """Schema for creating a new mantra"""
    pass


class MantraUpdate(BaseModel):
    """Schema for updating a mantra"""
    name: Optional[str] = Field(None, min_length=1, max_length=200)
    sanskrit: Optional[str] = Field(None, max_length=1000)
    gurmukhi: Optional[str] = Field(None, max_length=1000)
    translation: Optional[str] = Field(None, max_length=1000)
    category: Optional[MantraCategory] = None
    traditional_count: Optional[int] = Field(None, ge=1)
    audio_url: Optional[str] = Field(None, max_length=500)
    submitted_by: Optional[str] = Field(None, max_length=100)


class Mantra(MantraBase):
    """Full mantra model with database fields"""
    id: str
    source: MantraSource = MantraSource.USER
    submitted_at: datetime
    created_at: datetime
    updated_at: datetime
    user_id: str  # Associated user
    
    class Config:
        from_attributes = True