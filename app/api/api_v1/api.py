"""
API v1 router
"""
from fastapi import APIRouter

api_router = APIRouter()


@api_router.get("/mantras")
async def get_mantras():
    """Get all mantras"""
    return {
        "message": "Mantras endpoint",
        "data": [
            {
                "id": "m1",
                "name": "Mool Mantra",
                "category": "Fundamental",
                "text": "Ik Onkar Sat Nam Karta Purakh...",
                "language": "Gurmukhi"
            },
            {
                "id": "m2", 
                "name": "Waheguru",
                "category": "Simran",
                "text": "Waheguru",
                "language": "Gurmukhi"
            }
        ]
    }


@api_router.get("/recitations")
async def get_recitations():
    """Get all recitations"""
    return {
        "message": "Recitations endpoint",
        "data": []
    }


@api_router.post("/recitations")
async def create_recitation():
    """Create a new recitation"""
    return {
        "message": "Recitation created",
        "id": "r1"
    }