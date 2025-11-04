from pydantic import BaseModel, Field
from typing import Dict, List, Optional
from datetime import datetime

class CommandType(str):
    THROTTLE = "THROTTLE"
    SCALE = "SCALE"
    RESTART = "RESTART"
    CONFIG_UPDATE = "CONFIG_UPDATE"
    EMERGENCY_STOP = "EMERGENCY_STOP"

class Priority(str):
    LOW = "LOW"
    NORMAL = "NORMAL"
    HIGH = "HIGH"
    CRITICAL = "CRITICAL"

class RollbackConfig(BaseModel):
    enabled: bool = True
    timeout_seconds: int = 300
    previous_state: Dict[str, str] = {}

class ControlCommand(BaseModel):
    command_id: Optional[str] = None
    target_id: str = Field(..., description="Target device or system ID")
    command_type: str = Field(..., description="Command type")
    parameters: Dict[str, str] = Field(default_factory=dict)
    priority: str = "NORMAL"
    expiry: Optional[datetime] = None
    rollback_config: Optional[RollbackConfig] = None
    dry_run: bool = False

class CommandStatus(BaseModel):
    command_id: str
    status: str  # PENDING, EXECUTING, COMPLETED, FAILED, ROLLED_BACK
    created_at: datetime
    updated_at: datetime
    result: Optional[Dict] = None

class Alert(BaseModel):
    alert_id: str
    alert_type: str
    severity: str
    timestamp: datetime
    device_ids: List[str]
    title: str
    description: str
    metadata: Dict[str, str] = {}

class MetricQuery(BaseModel):
    metric_name: str
    device_id: Optional[str] = None
    time_range: int = 3600  # seconds

class Command(BaseModel):
    target_id: str
    command_type: str
    parameters: Dict[str, str] = {}
    dry_run: bool = False

class CommandResponse(BaseModel):
    command_id: str
    status: str