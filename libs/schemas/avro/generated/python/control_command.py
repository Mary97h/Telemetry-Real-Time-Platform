from dataclasses import dataclass
from typing import Dict, Optional

@dataclass
class RollbackConfig:
    enabled: bool
    timeout_seconds: int
    previous_state: Dict[str, str]

@dataclass
class ControlCommand:
    command_id: str
    target_id: str
    command_type: str  # Enum
    parameters: Dict[str, str]
    timestamp: int
    expiry: Optional[int] = None
    priority: str = "NORMAL"
    rollback_config: Optional[RollbackConfig] = None
    dry_run: bool = False