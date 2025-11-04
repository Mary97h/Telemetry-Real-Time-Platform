# docs/runbooks/scaling.md
# Scaling Runbook

## Overview
Handle load increases for horizontal scalability (≤{{latency_ms}} ms latency).

## Monitoring
- Metrics: Kafka lag >10k msgs, Flink backpressure, CPU>70%.
- Alerts: Grafana rules for thresholds.

## Vertical Scaling
- Increase resources: Edit Helm values (e.g., TaskManager CPU=8), `helm upgrade`.

## Horizontal Scaling
- Kafka: Add brokers via Strimzi, rebalance partitions.
- Flink: Use KEDA to auto-scale TaskManagers on lag.
- API: HPA on CPU, `kubectl autoscale deployment control-api --cpu-percent=70 --min=2 --max=10`.
- Redis/Postgres: Scale replicas, use read-replicas.

## Capacity Planning
- Load test: Use Locust on API, simulate 10k telemetry/sec.
- Limits: Set quotas in K8s namespaces.

## Rollback
- If scaling causes issues, downscale and monitor.