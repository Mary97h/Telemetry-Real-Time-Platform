from dataclasses import dataclass
from typing import Optional

@dataclass
class DeviceMetadata:
    location: str
    zone: str
    model: str
    firmware_version: Optional[str] = None

@dataclass
class EnrichedEvent:
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