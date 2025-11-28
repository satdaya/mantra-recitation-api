"""
Recitation service for Snowflake Iceberg table operations
"""

import uuid
import logging
from datetime import datetime
from typing import List, Optional
from snowflake.connector import DictCursor

from app.core.database import db
from app.models.recitation import RecitationCreate, RecitationUpdate, Recitation

logger = logging.getLogger(__name__)


class RecitationService:
    """Service for managing recitations in Snowflake Iceberg tables"""

    def __init__(self):
        self.db = db

    def _ensure_connection(self):
        """Ensure database connection is established"""
        if not self.db.connection:
            self.db.connect()

    def create_recitation(self, recitation: RecitationCreate, user_id: str) -> Recitation:
        """
        Create a new recitation record in Snowflake
        """
        self._ensure_connection()
        cursor = self.db.connection.cursor(DictCursor)

        try:
            recitation_id = str(uuid.uuid4())
            now = datetime.utcnow()

            insert_sql = """
                INSERT INTO recitations (
                    id, user_id, mantra_name, count, duration_minutes,
                    recitation_timestamp, notes, created_at, updated_at
                )
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
            """

            cursor.execute(insert_sql, (
                recitation_id,
                user_id,
                recitation.mantra_name,
                recitation.count,
                recitation.duration_minutes,
                recitation.recitation_timestamp,
                recitation.notes,
                now,
                now
            ))

            self.db.connection.commit()
            logger.info(f"Created recitation {recitation_id} for user {user_id}")

            # Return the created recitation
            return Recitation(
                id=recitation_id,
                user_id=user_id,
                mantra_name=recitation.mantra_name,
                count=recitation.count,
                duration_minutes=recitation.duration_minutes,
                recitation_timestamp=recitation.recitation_timestamp,
                notes=recitation.notes,
                created_at=now,
                updated_at=now
            )

        except Exception as e:
            self.db.connection.rollback()
            logger.error(f"Error creating recitation: {e}")
            raise
        finally:
            cursor.close()

    def get_recitations(
        self,
        user_id: str,
        start_date: Optional[datetime] = None,
        end_date: Optional[datetime] = None,
        limit: int = 100,
        offset: int = 0
    ) -> List[Recitation]:
        """
        Get recitations for a user with optional date filtering
        """
        self._ensure_connection()
        cursor = self.db.connection.cursor(DictCursor)

        try:
            query = """
                SELECT id, user_id, mantra_name, count, duration_minutes,
                       recitation_timestamp, notes, created_at, updated_at
                FROM recitations
                WHERE user_id = %s
            """
            params = [user_id]

            if start_date:
                query += " AND recitation_timestamp >= %s"
                params.append(start_date)

            if end_date:
                query += " AND recitation_timestamp <= %s"
                params.append(end_date)

            query += " ORDER BY recitation_timestamp DESC LIMIT %s OFFSET %s"
            params.extend([limit, offset])

            cursor.execute(query, params)
            rows = cursor.fetchall()

            return [
                Recitation(
                    id=row['ID'],
                    user_id=row['USER_ID'],
                    mantra_name=row['MANTRA_NAME'],
                    count=row['COUNT'],
                    duration_minutes=row['DURATION_MINUTES'],
                    recitation_timestamp=row['RECITATION_TIMESTAMP'],
                    notes=row['NOTES'],
                    created_at=row['CREATED_AT'],
                    updated_at=row['UPDATED_AT']
                )
                for row in rows
            ]

        except Exception as e:
            logger.error(f"Error fetching recitations: {e}")
            raise
        finally:
            cursor.close()

    def get_recitation_by_id(self, recitation_id: str, user_id: str) -> Optional[Recitation]:
        """
        Get a single recitation by ID
        """
        self._ensure_connection()
        cursor = self.db.connection.cursor(DictCursor)

        try:
            query = """
                SELECT id, user_id, mantra_name, count, duration_minutes,
                       recitation_timestamp, notes, created_at, updated_at
                FROM recitations
                WHERE id = %s AND user_id = %s
            """

            cursor.execute(query, (recitation_id, user_id))
            row = cursor.fetchone()

            if not row:
                return None

            return Recitation(
                id=row['ID'],
                user_id=row['USER_ID'],
                mantra_name=row['MANTRA_NAME'],
                count=row['COUNT'],
                duration_minutes=row['DURATION_MINUTES'],
                recitation_timestamp=row['RECITATION_TIMESTAMP'],
                notes=row['NOTES'],
                created_at=row['CREATED_AT'],
                updated_at=row['UPDATED_AT']
            )

        except Exception as e:
            logger.error(f"Error fetching recitation {recitation_id}: {e}")
            raise
        finally:
            cursor.close()

    def update_recitation(
        self,
        recitation_id: str,
        user_id: str,
        update_data: RecitationUpdate
    ) -> Optional[Recitation]:
        """
        Update an existing recitation
        """
        self._ensure_connection()
        cursor = self.db.connection.cursor(DictCursor)

        try:
            # Build dynamic update query based on provided fields
            updates = []
            params = []

            if update_data.mantra_name is not None:
                updates.append("mantra_name = %s")
                params.append(update_data.mantra_name)

            if update_data.count is not None:
                updates.append("count = %s")
                params.append(update_data.count)

            if update_data.duration_minutes is not None:
                updates.append("duration_minutes = %s")
                params.append(update_data.duration_minutes)

            if update_data.recitation_timestamp is not None:
                updates.append("recitation_timestamp = %s")
                params.append(update_data.recitation_timestamp)

            if update_data.notes is not None:
                updates.append("notes = %s")
                params.append(update_data.notes)

            if not updates:
                # No fields to update, return existing record
                return self.get_recitation_by_id(recitation_id, user_id)

            # Add updated_at timestamp
            updates.append("updated_at = %s")
            params.append(datetime.utcnow())

            # Add WHERE clause params
            params.extend([recitation_id, user_id])

            update_sql = f"""
                UPDATE recitations
                SET {', '.join(updates)}
                WHERE id = %s AND user_id = %s
            """

            cursor.execute(update_sql, params)
            self.db.connection.commit()

            logger.info(f"Updated recitation {recitation_id}")

            # Return updated record
            return self.get_recitation_by_id(recitation_id, user_id)

        except Exception as e:
            self.db.connection.rollback()
            logger.error(f"Error updating recitation {recitation_id}: {e}")
            raise
        finally:
            cursor.close()

    def delete_recitation(self, recitation_id: str, user_id: str) -> bool:
        """
        Delete a recitation
        """
        self._ensure_connection()
        cursor = self.db.connection.cursor()

        try:
            delete_sql = """
                DELETE FROM recitations
                WHERE id = %s AND user_id = %s
            """

            cursor.execute(delete_sql, (recitation_id, user_id))
            rows_deleted = cursor.rowcount
            self.db.connection.commit()

            logger.info(f"Deleted recitation {recitation_id}: {rows_deleted} rows affected")
            return rows_deleted > 0

        except Exception as e:
            self.db.connection.rollback()
            logger.error(f"Error deleting recitation {recitation_id}: {e}")
            raise
        finally:
            cursor.close()


# Global service instance
recitation_service = RecitationService()


def get_recitation_service() -> RecitationService:
    """Dependency for FastAPI to get recitation service"""
    return recitation_service
