#!/bin/bash
set -e

echo "Starting Real-Time Telemetry Platform (Local Mode)"
echo "=================================================="

# Check prerequisites
command -v docker >/dev/null 2>&1 || { echo "Docker is required but not installed."; exit 1; }
command -v docker-compose >/dev/null 2>&1 || { echo "docker-compose is required but not installed."; exit 1; }

# Create necessary directories
mkdir -p scripts/sql
mkdir -p infra/monitoring

# Start Docker Compose
echo ""
echo "Starting containers..."
docker-compose up -d

# Wait for services to be ready
echo ""
echo "Waiting for services to be ready..."

# Wait for Zookeeper
echo -n "  Zookeeper..."
timeout 60 bash -c 'until docker exec zookeeper bash -c "echo ruok | nc localhost 2181" | grep -q imok 2>/dev/null; do sleep 2; done' && echo " OK" || echo " FAILED"

# Wait for Kafka brokers
for broker in kafka-1 kafka-2 kafka-3; do
    echo -n "  $broker..."
    timeout 90 bash -c "until docker logs $broker 2>&1 | grep -q 'started (kafka.server.KafkaServer)'; do sleep 3; done" && echo " OK" || echo " FAILED"
done

# Wait for Schema Registry
echo -n "  Schema Registry..."
timeout 60 bash -c 'until curl -sf http://localhost:8081/subjects >/dev/null 2>&1; do sleep 2; done' && echo " OK" || echo " FAILED"

# Wait for Postgres
echo -n "  PostgreSQL..."
timeout 60 bash -c 'until docker exec postgres pg_isready -U admin >/dev/null 2>&1; do sleep 2; done' && echo " OK" || echo " FAILED"

# Wait for Redis
echo -n "  Redis..."
timeout 60 bash -c 'until docker exec redis redis-cli ping 2>&1 | grep -q PONG; do sleep 2; done' && echo " OK" || echo " FAILED"

# Wait for Prometheus
echo -n "  Prometheus..."
timeout 60 bash -c 'until curl -sf http://localhost:9090/-/ready >/dev/null 2>&1; do sleep 2; done' && echo " OK" || echo " FAILED"

# Wait for Grafana
echo -n "  Grafana..."
timeout 60 bash -c 'until curl -sf http://localhost:3000/api/health >/dev/null 2>&1; do sleep 2; done' && echo " OK" || echo " FAILED"

# Wait for MinIO
echo -n "  MinIO..."
timeout 60 bash -c 'until curl -sf http://localhost:9000/minio/health/live >/dev/null 2>&1; do sleep 2; done' && echo " OK" || echo " FAILED"

# Create Kafka topics
echo ""
echo "Creating Kafka topics..."
docker exec kafka-1 kafka-topics --bootstrap-server kafka-1:9092 --create --if-not-exists \
    --topic telemetry.raw \
    --partitions 12 \
    --replication-factor 3 \
    --config retention.ms=604800000 \
    --config min.insync.replicas=2 && echo "  telemetry.raw created"

docker exec kafka-1 kafka-topics --bootstrap-server kafka-1:9092 --create --if-not-exists \
    --topic telemetry.enriched \
    --partitions 12 \
    --replication-factor 3 \
    --config retention.ms=604800000 \
    --config min.insync.replicas=2 && echo "  telemetry.enriched created"

docker exec kafka-1 kafka-topics --bootstrap-server kafka-1:9092 --create --if-not-exists \
    --topic telemetry.aggregated \
    --partitions 6 \
    --replication-factor 3 \
    --config retention.ms=2592000000 \
    --config min.insync.replicas=2 && echo "  telemetry.aggregated created"

docker exec kafka-1 kafka-topics --bootstrap-server kafka-1:9092 --create --if-not-exists \
    --topic telemetry.alerts \
    --partitions 6 \
    --replication-factor 3 \
    --config retention.ms=2592000000 \
    --config min.insync.replicas=2 && echo "  telemetry.alerts created"

docker exec kafka-1 kafka-topics --bootstrap-server kafka-1:9092 --create --if-not-exists \
    --topic control.commands \
    --partitions 6 \
    --replication-factor 3 \
    --config retention.ms=604800000 \
    --config min.insync.replicas=2 && echo "  control.commands created"

docker exec kafka-1 kafka-topics --bootstrap-server kafka-1:9092 --create --if-not-exists \
    --topic control.feedback \
    --partitions 6 \
    --replication-factor 3 \
    --config retention.ms=604800000 \
    --config min.insync.replicas=2 && echo "  control.feedback created"

# Initialize MinIO buckets
echo ""
echo "Creating MinIO buckets..."
docker exec minio mc alias set local http://localhost:9000 admin telemetry-minio-2024 2>/dev/null || true
docker exec minio mc mb local/telemetry-checkpoints --ignore-existing && echo "  telemetry-checkpoints created"
docker exec minio mc mb local/telemetry-archives --ignore-existing && echo "  telemetry-archives created"

echo ""
echo "All services are ready!"
echo ""
echo "Access Points:"
echo "  Grafana:         http://localhost:3000 (admin/admin)"
echo "  Prometheus:      http://localhost:9090"
echo "  Kafka UI:        http://localhost:8080"
echo "  Schema Registry: http://localhost:8081"
echo "  MinIO Console:   http://localhost:9001 (admin/telemetry-minio-2024)"
echo ""
echo "Connection Details:"
echo "  Kafka Bootstrap: localhost:19092,localhost:19093,localhost:19094"
echo "  PostgreSQL:      localhost:5432 (admin/telemetry-secret-2024)"
echo "  Redis:           localhost:6379"
echo ""
echo "Next: Run 'make kind-up' to create Kubernetes cluster"
