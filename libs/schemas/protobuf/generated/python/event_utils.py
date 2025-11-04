from typing import Dict, Any

def extract_timestamp(record: Dict[str, Any]) -> int:
    return record.get('timestamp', 0)

def get_metrics(record: Dict[str, Any]) -> Dict[str, float]:
    return record.get('metrics', {})
