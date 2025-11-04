"""
Control API Service
REST/gRPC API for adaptive control loop and command generation
"""

import os
import logging
from typing import List, Dict, Optional
from datetime import datetime, timedelta
from contextlib import asynccontextmanager

from fastapi import FastAPI, HTTPException, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
import uvicorn
from kafka import KafkaProducer, KafkaConsumer
from kafka.errors import KafkaError
import redis
import psycopg2
from psycopg2.extras import RealDictCursor
import json

from config import *
from models import *
from alerts import list_alerts as db_list_alerts  # Renamed to avoid conflict
from commands import validate_safe_guards, store_command_audit, schedule_rollback, generate_inverse_command
from metrics import get_metric as db_get_metric  # Renamed

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Global resources
kafka_producer = None
redis_client = None
db_pool = None

@asynccontextmanager
async def lifespan(app: FastAPI):
    """Initialize resources on startup, cleanup on shutdown"""
    global kafka_producer, redis_client, db_pool
    
    logger.info("Initializing Control API service...")
    
    # Initialize Kafka producer
    try:
        kafka_producer = KafkaProducer(
            bootstrap_servers=KAFKA_BOOTSTRAP_SERVERS,
            value_serializer=lambda v: json.dumps(v).encode('utf-8'),
            acks='all',
            retries=3,
            enable_idempotence=True
        )
        logger.info("Kafka producer initialized")
    except Exception as e:
        logger.error(f"Failed to initialize Kafka producer: {e}")
    
    # Initialize Redis client
    try:
        redis_client = redis.Redis(
            host=REDIS_HOST,
            port=REDIS_PORT,
            decode_responses=True
        )
        redis_client.ping()
        logger.info("Redis client initialized")
    except Exception as e:
        logger.error(f"Failed to initialize Redis: {e}")
    
    # Initialize Postgres connection pool
    try:
        db_pool = psycopg2.pool.SimpleConnectionPool(
            1, 20,
            host=POSTGRES_HOST,
            port=POSTGRES_PORT,
            user=POSTGRES_USER,
            password=POSTGRES_PASSWORD,
            database=POSTGRES_DB
        )
        logger.info("Postgres connection pool initialized")
    except Exception as e:
        logger.error(f"Failed to initialize Postgres pool: {e}")
    
    logger.info("Control API service ready!")
    
    yield
    
    # Cleanup on shutdown
    logger.info("Shutting down Control API service...")
    if kafka_producer:
        kafka_producer.close()
    if redis_client:
        redis_client.close()
    if db_pool:
        db_pool.closeall()

# Create FastAPI app
app = FastAPI(
    title="Telemetry Control API",
    description="Adaptive control API for real-time telemetry platform",
    version="1.0.0",
    lifespan=lifespan
)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/health")
async def health_check():
    """Health check endpoint"""
    status = {
        "status": "healthy",
        "kafka": "unknown",
        "redis": "unknown",
        "postgres": "unknown"
    }
    
    # Check Kafka
    try:
        if kafka_producer:
            status["kafka"] = "connected"
    except:
        status["kafka"] = "disconnected"
    
    # Check Redis
    try:
        if redis_client:
            redis_client.ping()
            status["redis"] = "connected"
    except:
        status["redis"] = "disconnected"
    
    # Check Postgres
    try:
        if db_pool:
            conn = db_pool.getconn()
            conn.close()
            db_pool.putconn(conn)
            status["postgres"] = "connected"
    except:
        status["postgres"] = "disconnected"
    
    return status

@app.get("/metrics/{metric_name}")
async def get_metric(metric_name: str, device_id: Optional[str] = None):
    """Get cached metric values from Redis"""
    try:
        return await db_get_metric(metric_name, device_id)
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))
    except Exception as e:
        logger.error(f"Error fetching metric: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/alerts")
async def list_alerts(
    severity: Optional[str] = None,
    limit: int = 100
):
    """List recent alerts"""
    try:
        alerts = await db_list_alerts(severity, limit)
        return {"alerts": alerts, "count": len(alerts)}
    
    except Exception as e:
        logger.error(f"Error fetching alerts: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/commands")
async def create_command(command: ControlCommand, background_tasks: BackgroundTasks):
    """
    Create and execute a control command
    
    This implements the adaptive control loop:
    1. Validate command and check safe-guards
    2. Store in audit log
    3. Publish to Kafka control-commands topic
    4. Schedule rollback timer if enabled
    """
    try:
        # Generate command ID if not provided
        if not command.command_id:
            command.command_id = f"cmd_{datetime.utcnow().timestamp()}"
        
        # Apply safe-guards
        if not await validate_safe_guards(command):
            raise HTTPException(
                status_code=400,
                detail="Command failed safe-guard validation"
            )
        
        # Store in audit log (Postgres)
        await store_command_audit(command)
        
        # Publish to Kafka
        if not command.dry_run:
            command_dict = command.dict()
            command_dict['timestamp'] = datetime.utcnow().isoformat()
            
            future = kafka_producer.send(
                'control-commands',
                key=command.target_id.encode('utf-8'),
                value=command_dict
            )
            
            # Wait for send confirmation
            record_metadata = future.get(timeout=10)
            logger.info(f"Command published: {command.command_id} to partition {record_metadata.partition}")
        
        # Schedule rollback if enabled
        if command.rollback_config and command.rollback_config.enabled:
            background_tasks.add_task(
                schedule_rollback,
                command.command_id,
                command.rollback_config.timeout_seconds
            )
        
        return {
            "command_id": command.command_id,
            "status": "PENDING",
            "dry_run": command.dry_run,
            "message": "Command created successfully"
        }
    
    except KafkaError as e:
        logger.error(f"Kafka error: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to publish command: {str(e)}")
    except Exception as e:
        logger.error(f"Error creating command: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/commands/{command_id}")
async def get_command_status(command_id: str):
    """Get command execution status"""
    try:
        conn = db_pool.getconn()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        
        cur.execute(
            "SELECT * FROM command_audit WHERE command_id = %s",
            (command_id,)
        )
        command = cur.fetchone()
        
        cur.close()
        db_pool.putconn(conn)
        
        if not command:
            raise HTTPException(status_code=404, detail="Command not found")
        
        return command
    
    except Exception as e:
        logger.error(f"Error fetching command: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/commands/{command_id}/rollback")
async def rollback_command(command_id: str):
    """Manually trigger command rollback"""
    try:
        # Fetch original command
        conn = db_pool.getconn()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        
        cur.execute(
            "SELECT * FROM command_audit WHERE command_id = %s",
            (command_id,)
        )
        original_command = cur.fetchone()
        
        if not original_command:
            raise HTTPException(status_code=404, detail="Command not found")
        
        # Generate inverse command
        rollback_cmd = generate_inverse_command(original_command)
        
        # Publish rollback command
        kafka_producer.send(
            'control-commands',
            key=rollback_cmd['target_id'].encode('utf-8'),
            value=rollback_cmd
        )
        
        # Update command status
        cur.execute(
            "UPDATE command_audit SET status = 'ROLLED_BACK', updated_at = NOW() WHERE command_id = %s",
            (command_id,)
        )
        conn.commit()
        
        cur.close()
        db_pool.putconn(conn)
        
        logger.info(f"Command {command_id} rolled back")
        
        return {
            "command_id": command_id,
            "status": "ROLLED_BACK",
            "rollback_command_id": rollback_cmd['command_id']
        }
    
    except Exception as e:
        logger.error(f"Error rolling back command: {e}")
        raise HTTPException(status_code=500, detail=str(e))



if __name__ == "__main__":
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=8000,
        log_level="info",
        reload=False
    )