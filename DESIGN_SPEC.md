### `DESIGN_SPEC.md`
```markdown
# Design Specification (v0)

## Goals
- Low-latency ingestion and processing of telemetry streams.
- Exactly-once processing with Flink.
- Adaptive control loop via Control API producing `control-commands`.

## Data Flow
Device → Kafka `telemetry-raw` → Flink jobs (windows/CEP) → Kafka `telemetry-processed` and alerts → Control API consumes alerts (future) and emits `control-commands`.

## Components
- **Kafka** (dev: single broker with ZooKeeper)
- **Flink** (JobManager/TaskManager)
- **Control API** (FastAPI + Redis + Postgres)
- **Schema Registry** (for Avro, optional at first)


