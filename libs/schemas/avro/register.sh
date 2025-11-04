#!/bin/bash
# Register schemas with Confluent Schema Registry

set -e

SCHEMA_REGISTRY_URL=${SCHEMA_REGISTRY_URL:-"http://localhost:8081"}

echo "Registering schemas with Schema Registry at $SCHEMA_REGISTRY_URL"

register_schema() {
    local subject=$1
    local schema_file=$2
    
    echo "Registering $subject..."
    
    # Escape the schema JSON for the API request
    schema_json=$(cat "$schema_file" | jq -c . | jq -R .)
    
    curl -X POST -H "Content-Type: application/vnd.schemaregistry.v1+json" \
        --data "{\"schema\": $schema_json}" \
        "$SCHEMA_REGISTRY_URL/subjects/$subject/versions"
    
    echo ""
}

# Register Avro schemas
register_schema "telemetry-raw-value" "avro/TelemetryEvent.avsc"
register_schema "enriched-events-value" "avro/EnrichedEvent.avsc"
register_schema "alerts-value" "avro/Alert.avsc"
register_schema "control-commands-value" "avro/ControlCommand.avsc"

echo "Schema registration complete!"

# List all registered schemas
echo "Registered subjects:"
curl -s "$SCHEMA_REGISTRY_URL/subjects" | jq .
