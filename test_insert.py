#!/usr/bin/env python
"""Test inserting a recitation directly"""

from datetime import datetime
from app.services.recitation_service import recitation_service
from app.models.recitation import RecitationCreate

print('=== Testing Direct Insert ===')

# Create a test recitation
test_recitation = RecitationCreate(
    mantra_name="Test Mantra",
    count=108,
    duration_minutes=15,
    recitation_timestamp=datetime.now(),
    notes="Test from script"
)

try:
    print(f'Inserting: {test_recitation.mantra_name}...')
    result = recitation_service.create_recitation(
        recitation=test_recitation,
        user_id="default-user"
    )
    print(f'✅ Success! Created recitation ID: {result.id}')
    print(f'Details: {result}')
except Exception as e:
    print(f'❌ Failed to insert!')
    print(f'Error: {e}')
    import traceback
    traceback.print_exc()
