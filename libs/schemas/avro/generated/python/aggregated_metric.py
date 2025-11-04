from dataclasses import dataclass
from typing import Dict

@dataclass
class AggregatedMetric:
    device_id: str
    timestamp: int
    window_start: int
    window_end: int
    avg_metrics: Dict[str, float]
    min_metrics: Dict[str, float]
    max_metrics: Dict[str, float]
    count: int