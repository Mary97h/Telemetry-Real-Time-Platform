#!/bin/bash
set -e

echo "Deploying Flink Applications"

NAMESPACE="telemetry-platform"

# Build Flink jobs (if Java source exists)
if [ -d "apps/flink-jobs" ]; then
  echo "Building Flink jobs..."
  # Placeholder - in real scenario, would build with Maven/Gradle
  # cd apps/flink-jobs && mvn clean package -DskipTests
  echo "Skipping build (using pre-built images in demo)"
fi

# Deploy Ingest Job
echo ""
echo "Deploying Ingest Job..."
helm upgrade --install flink-ingest-job infra/helm/flink-app \
  --namespace $NAMESPACE \
  --set app.name=flink-ingest-job \
  --set app.jobName="Telemetry Ingest Job" \
  --set app.image="flink:1.18-scala_2.12-java11" \
  --set app.jarPath="/opt/flink/examples/streaming/StateMachineExample.jar" \
  --set app.parallelism=2 \
  --set jobManager.replicas=1 \
  --set taskManager.replicas=2 \
  --set resources.jobManager.memory="2048m" \
  --set resources.taskManager.memory="4096m" \
  --set resources.taskManager.cpu=2 \
  --set checkpoint.interval=60000 \
  --set checkpoint.minPause=30000 \
  --set checkpoint.timeout=600000 \
  --set savepoint.directory="file:///flink-checkpoints/savepoints" \
  --set kafka.bootstrapServers="host.docker.internal:19092" \
  --set kafka.inputTopic="telemetry.raw" \
  --set kafka.outputTopic="telemetry.enriched" \
  --set kafka.consumerGroup="flink-ingest-job" \
  --wait --timeout 5m

echo "Ingest Job deployed"

# Deploy Aggregator Job
echo ""
echo "Deploying Aggregator Job..."
helm upgrade --install flink-aggregator-job infra/helm/flink-app \
  --namespace $NAMESPACE \
  --set app.name=flink-aggregator-job \
  --set app.jobName="Telemetry Aggregator Job" \
  --set app.image="flink:1.18-scala_2.12-java11" \
  --set app.jarPath="/opt/flink/examples/streaming/StateMachineExample.jar" \
  --set app.parallelism=2 \
  --set jobManager.replicas=1 \
  --set taskManager.replicas=2 \
  --set resources.jobManager.memory="2048m" \
  --set resources.taskManager.memory="4096m" \
  --set resources.taskManager.cpu=2 \
  --set checkpoint.interval=60000 \
  --set savepoint.directory="file:///flink-checkpoints/savepoints" \
  --set kafka.bootstrapServers="host.docker.internal:19092" \
  --set kafka.inputTopic="telemetry.enriched" \
  --set kafka.outputTopic="telemetry.aggregated" \
  --set kafka.consumerGroup="flink-aggregator-job" \
  --wait --timeout 5m

echo "Aggregator Job deployed"

# Deploy CEP Job
echo ""
echo "Deploying CEP Anomaly Detection Job..."
helm upgrade --install flink-cep-job infra/helm/flink-app \
  --namespace $NAMESPACE \
  --set app.name=flink-cep-job \
  --set app.jobName="CEP Anomaly Detection Job" \
  --set app.image="flink:1.18-scala_2.12-java11" \
  --set app.jarPath="/opt/flink/examples/streaming/StateMachineExample.jar" \
  --set app.parallelism=2 \
  --set jobManager.replicas=1 \
  --set taskManager.replicas=2 \
  --set resources.jobManager.memory="2048m" \
  --set resources.taskManager.memory="4096m" \
  --set checkpoint.interval=60000 \
  --set savepoint.directory="file:///flink-checkpoints/savepoints" \
  --set kafka.bootstrapServers="host.docker.internal:19092" \
  --set kafka.inputTopic="telemetry.enriched" \
  --set kafka.outputTopic="telemetry.alerts" \
  --set kafka.consumerGroup="flink-cep-job" \
  --wait --timeout 5m

echo "CEP Job deployed"

echo ""
echo "All Flink applications deployed successfully"
echo ""
echo "Check job status:"
echo "  kubectl get flinkdeployment -n $NAMESPACE"
echo ""
echo "View Flink UI:"
echo "  kubectl port-forward -n $NAMESPACE svc/flink-ingest-job-rest 8081:8081"
