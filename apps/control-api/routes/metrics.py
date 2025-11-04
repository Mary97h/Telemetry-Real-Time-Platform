import logging
from typing import Optional, Dict
from datetime import datetime
import json
import redis

from config import redis_client

logger = logging.getLogger(__name__)

async def store_metric(metric_name: str, value: Dict, device_id: Optional[str] = None, ttl: int = 3600):
    """Store metric in Redis with TTL"""
    try:
        if device_id:
            key = f"metric:{metric_name}:{device_id}"
        else:
            key = f"metric:{metric_name}:global"
        
        redis_client.setex(key, ttl, json.dumps(value))
        logger.info(f"Metric stored: {key}")
    
    except Exception as e:
        logger.error(f"Error storing metric: {e}")
        raise

async def get_metric(metric_name: str, device_id: Optional[str] = None) -> Dict:
    """Get metric from Redis"""
    try:
        if device_id:
            key = f"metric:{metric_name}:{device_id}"
        else:
            key = f"metric:{metric_name}:global"
        
        value = redis_client.get(key)
        if value is None:
            raise ValueError("Metric not found")
        
        return {
            "metric_name": metric_name,
            "device_id": device_id,
            "value": json.loads(value),
            "timestamp": datetime.utcnow().isoformat()
        }
    
    except Exception as e:
        logger.error(f"Error fetching metric: {e}")
        raise