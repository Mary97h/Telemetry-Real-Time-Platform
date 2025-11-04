
```markdown
# docs/api/rest-api.md
# REST API Documentation

This is the RESTful Control API for managing commands, alerts, and metrics in the telemetry platform.

## Base URL
`https://control-api.telemetry/v1`

## Authentication
- JWT Bearer tokens.
- Rate limiting: 100 req/min.

## Endpoints

### Health Check
- **GET /health**
  - Response: JSON object with status of services (Kafka, Redis, Postgres).
  - Example: `{"status": "healthy", "kafka": "connected"}`

### Metrics
- **GET /metrics/{metric_name}**
  - Query Params: `device_id` (optional)
  - Response: Cached metric value from Redis.
  - Example: `{"metric_name": "latency", "value": {"avg": 50.2}}`

### Alerts
- **GET /alerts**
  - Query Params: `severity` (optional), `limit` (default 100)
  - Response: List of recent alerts from Postgres.
  - Example: `{"alerts": [{"alert_id": "a1", "severity": "HIGH"}], "count": 1}`

### Commands
- **POST /commands**
  - Body: JSON `ControlCommand` (see models.py)
  - Response: Command ID and status.
  - Validates safeguards, audits in Postgres, publishes to Kafka.

- **GET /commands/{command_id}**
  - Response: Command status from audit log.

- **POST /commands/{command_id}/rollback**
  - Triggers inverse command and updates status.

## Error Handling
- 4xx: Client errors (e.g., 400 for invalid command).
- 5xx: Server errors (e.g., 500 for Kafka failure).

For code, see `apps/control-api/main.py`.