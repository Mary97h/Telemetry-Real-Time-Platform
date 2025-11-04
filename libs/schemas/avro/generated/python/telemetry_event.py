from dataclasses import dataclass
from typing import Dict, Optional

@dataclass
class TelemetryEvent:
    event_id: str
    device_id: str
    timestamp: int
    sensor_type: str
    value: float
    unit: str
    quality: Optional[int] = None
    tags: Dict[str, str] = None