import logging
from typing import Dict
from datetime import datetime
import asyncio
import redis
import psycopg2
from psycopg2.extras import RealDictCursor

from config import redis_client, db_pool, kafka_producer
from models import ControlCommand

logger = logging.getLogger(__name__)

async def validate_safe_guards(command: ControlCommand) -> bool:
    """
    Validate command against safe-guards:
    1. Rate limiting
    2. Blast radius check
    3. Circuit breaker
    """
    # Rate limiting: max 10 commands/min per target
    rate_key = f"rate_limit:commands:{command.target_id}"
    count = redis_client.incr(rate_key)
    if count == 1:
        redis_client.expire(rate_key, 60)
    
    if count > 10:
        logger.warning(f"Rate limit exceeded for target {command.target_id}")
        return False
    
    # Blast radius check (if affecting multiple devices)
    if command.command_type == "EMERGENCY_STOP":
        # Example: Query Postgres for device count
        conn = db_pool.getconn()
        cur = conn.cursor()
        cur.execute("SELECT COUNT(*) FROM devices WHERE group_id = %s", (command.parameters.get('group_id'),))
        count = cur.fetchone()[0]
        cur.close()
        db_pool.putconn(conn)
        if count > 100:  # Arbitrary threshold for 20% of fleet
            logger.warning(f"Blast radius too large for {command.target_id}")
            return False
    
    # Circuit breaker check
    circuit_key = "circuit_breaker:control_api"
    error_rate = redis_client.get(circuit_key)
    if error_rate and float(error_rate) > 0.1:
        logger.warning("Circuit breaker open - too many errors")
        return False
    
    return True

async def store_command_audit(command: ControlCommand):
    """Store command in Postgres audit log"""
    try:
        conn = db_pool.getconn()
        cur = conn.cursor()
        
        cur.execute("""
            INSERT INTO command_audit 
            (command_id, target_id, command_type, parameters, priority, status, created_at, updated_at)
            VALUES (%s, %s, %s, %s, %s, %s, NOW(), NOW())
        """, (
            command.command_id,
            command.target_id,
            command.command_type,
            json.dumps(command.parameters),
            command.priority,
            'PENDING'
        ))
        
        conn.commit()
        cur.close()
        db_pool.putconn(conn)
    
    except Exception as e:
        logger.error(f"Error storing command audit: {e}")
        raise

async def schedule_rollback(command_id: str, timeout_seconds: int):
    """Schedule automatic rollback after timeout"""
    await asyncio.sleep(timeout_seconds)
    
    # Check if command is still pending or executing
    conn = db_pool.getconn()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    
    cur.execute(
        "SELECT status FROM command_audit WHERE command_id = %s",
        (command_id,)
    )
    result = cur.fetchone()
    
    cur.close()
    db_pool.putconn(conn)
    
    if result and result['status'] in ['PENDING', 'EXECUTING']:
        logger.warning(f"Auto-rollback triggered for command {command_id}")
        # Trigger rollback (implement actual call to rollback logic)

def generate_inverse_command(original_command: Dict) -> Dict:
    """Generate inverse command for rollback"""
    inverse_type = {
        "THROTTLE": "UNTHROTTLE",
        "SCALE": "DESCALE",
        "RESTART": "NOOP",  # Restart can't be inverted easily
        "CONFIG_UPDATE": "CONFIG_REVERT",
        "EMERGENCY_STOP": "RESUME"
    }.get(original_command['command_type'], "ROLLBACK")
    
    rollback_cmd = {
        'command_id': f"rollback_{original_command['command_id']}",
        'target_id': original_command['target_id'],
        'command_type': inverse_type,
        'parameters': original_command.get('rollback_config', {}).get('previous_state', {}),
        'priority': 'HIGH',
        'timestamp': datetime.utcnow().isoformat()
    }
    return rollback_cmd