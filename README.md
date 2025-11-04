# Telemetry Realtime Platform

Kafka + Flink + FastAPI (Control API) + Postgres + Redis for real-time telemetry and adaptive control.

## Quickstart (Docker Compose)
```bash
docker compose up -d
# Open http://localhost:8000/docs  (Control API)
# Open http://localhost:8081       (Flink UI, once jobman/taskman are up)
