from dataclasses import dataclass
from typing import List, Dict, Optional

@dataclass
class Alert:
    alert_id: str
    alert_type: str  # Enum: THRESHOLD, etc.
    severity: str  # Enum: INFO, etc.
    timestamp: int
    device_ids: List[str]
    title: str
    description: str
    metadata: Dict[str, str]
    recommended_action: Optional[str] = None