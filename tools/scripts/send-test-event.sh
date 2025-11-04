#!/bin/bash
set -e

echo "Sending test telemetry event"

# Check if Kafka is running
if ! docker ps | grep -q kafka-1; then
  echo "Kafka is not running. Start with: make docker-up"
  exit 1
fi

# Generate test event
DEVICE_ID="test-device-$(date +%s)"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
EVENT_ID="evt-$(uuidgen 2>/dev/null || echo $(date +%s)-$(shuf -i 1000-9999 -n 1))"

TEST_EVENT=$(cat <<EOF
{
  "event_id": "$EVENT_ID",
  "device_id": "$DEVICE_ID",
  "timestamp": "$TIMESTAMP",
  "event_type": "sensor_reading",
  "payload": {
    "temperature": 72.5,
    "humidity": 45.2,
    "pressure": 1013.25,
    "battery_level": 87
  },
  "metadata": {
    "firmware_version": "v1.2.3",
    "location": "datacenter-1",
    "zone": "A"
  }
}
EOF
)

echo ""
echo "📋 Test Event:"
echo "$TEST_EVENT" | jq .

echo ""
echo "📨 Sending to Kafka topic: telemetry.raw"

# Send to Kafka
echo "$TEST_EVENT" | docker exec -i kafka-1 kafka-console-producer \
  --bootstrap-server localhost:9092 \
  --topic telemetry.raw \
  --property "parse.key=true" \
  --property "key.separator=:" <<< "$DEVICE_ID:$TEST_EVENT"

echo ""
echo "✅ Event sent successfully!"
echo ""
echo "🔍 Verify event:"
echo "  1. Check Flink logs:"
echo "     kubectl logs -n telemetry-platform -l app=flink-ingest-job --tail=20"
echo ""
echo "  2. Consume from enriched topic:"
echo "     make kafka-consume TOPIC=telemetry.enriched"
echo ""
echo "  3. Query Postgres:"
echo "     docker exec postgres psql -U admin -d telemetry -c \"SELECT * FROM aggregated_metrics ORDER BY timestamp DESC LIMIT 5;\""
