import logging
from typing import List, Dict
from datetime import datetime
import psycopg2
from psycopg2.extras import RealDictCursor

from config import db_pool

logger = logging.getLogger(__name__)

async def store_alert(alert: Dict):
    """Store alert in Postgres"""
    try:
        conn = db_pool.getconn()
        cur = conn.cursor()
        
        cur.execute("""
            INSERT INTO alerts 
            (alert_id, alert_type, severity, timestamp, device_ids, title, description, metadata)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
        """, (
            alert['alert_id'],
            alert['alert_type'],
            alert['severity'],
            alert['timestamp'],
            alert['device_ids'],
            alert['title'],
            alert['description'],
            psycopg2.Binary(json.dumps(alert['metadata']))
        ))
        
        conn.commit()
        cur.close()
        db_pool.putconn(conn)
        logger.info(f"Alert stored: {alert['alert_id']}")
    
    except Exception as e:
        logger.error(f"Error storing alert: {e}")
        raise

async def get_alerts_by_severity(severity: str, limit: int = 100) -> List[Dict]:
    """Fetch alerts by severity"""
    try:
        conn = db_pool.getconn()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        
        cur.execute("""
            SELECT * FROM alerts 
            WHERE severity = %s 
            ORDER BY timestamp DESC 
            LIMIT %s
        """, (severity, limit))
        
        alerts = cur.fetchall()
        cur.close()
        db_pool.putconn(conn)
        return alerts
    
    except Exception as e:
        logger.error(f"Error fetching alerts by severity: {e}")
        raise