# docs/runbooks/disaster-recovery.md
# Disaster Recovery Runbook

## Overview
Recover from failures like data loss, outages in Kafka/Flink/K8s.

## Preparation
- Backups: Daily pg_dump for Postgres, Kafka MirrorMaker2 for topics, S3 versioning for checkpoints.
- Monitoring: Grafana alerts on downtime >5min.

## Steps for Kafka Outage
1. Check Strimzi status: `kubectl get kafka -n telemetry`.
2. Failover to secondary cluster: Update bootstrap servers in env vars.
3. Restore topics: Use MirrorMaker2 to sync from geo-replica.

## Steps for Flink Job Failure
1. Check Operator: `kubectl logs flink-operator`.
2. Restore from savepoint: `flink savepoint <job-id> s3://savepoints/`.
3. Restart: Scale TaskManagers via KEDA/HPA.

## Testing
- Chaos engineering: Use Chaos Mesh to simulate pod kills.
- DR Drill: Quarterly, simulate AZ failure.

## Contacts
- On-call: ops@telemetry.com