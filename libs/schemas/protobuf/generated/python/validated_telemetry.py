# (Placeholder)
from dataclasses import dataclass
from typing import Optional

from enriched_event import DeviceMetadata  

@dataclass
class ValidatedTelemetry:
    event_id: str
    device_id: str
    timestamp: int
    sensor_type: str
    value: float
    unit: str
    device_metadata: DeviceMetadata
    processed_timestamp: int
    anomaly_score: Optional[float] = None
    quality_score: float = 1.0
    valid: bool = True