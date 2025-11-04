#!/bin/bash
set -e

echo " Deploying KEDA ScaledObjects"

NAMESPACE="telemetry-platform"

# Create ScaledObject for Flink TaskManagers based on Kafka lag
echo ""
echo " Creating KEDA ScaledObjects..."

cat <<EOF | kubectl apply -f -
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: flink-ingest-job-scaler
  namespace: $NAMESPACE
spec:
  scaleTargetRef:
    apiVersion: flink.apache.org/v1beta1
    kind: FlinkDeployment
    name: flink-ingest-job
  pollingInterval: 30
  cooldownPeriod: 300
  minReplicaCount: 2
  maxReplicaCount: 10
  triggers:
  - type: kafka
    metadata:
      bootstrapServers: host.docker.internal:19092
      consumerGroup: flink-ingest-job
      topic: telemetry.raw
      lagThreshold: "1000"
      activationLagThreshold: "500"
---
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: flink-aggregator-job-scaler
  namespace: $NAMESPACE
spec:
  scaleTargetRef:
    apiVersion: flink.apache.org/v1beta1
    kind: FlinkDeployment
    name: flink-aggregator-job
  pollingInterval: 30
  cooldownPeriod: 300
  minReplicaCount: 2
  maxReplicaCount: 8
  triggers:
  - type: kafka
    metadata:
      bootstrapServers: host.docker.internal:19092
      consumerGroup: flink-aggregator-job
      topic: telemetry.enriched
      lagThreshold: "1000"
      activationLagThreshold: "500"
---
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: control-api-scaler
  namespace: $NAMESPACE
spec:
  scaleTargetRef:
    name: control-api
  pollingInterval: 30
  cooldownPeriod: 300
  minReplicaCount: 2
  maxReplicaCount: 10
  triggers:
  - type: cpu
    metricType: Utilization
    metadata:
      value: "70"
  - type: memory
    metricType: Utilization
    metadata:
      value: "80"
EOF

echo "   ScaledObjects created"

# Create TriggerAuthentication for secure connections
cat <<EOF | kubectl apply -f -
apiVersion: keda.sh/v1alpha1
kind: TriggerAuthentication
metadata:
  name: kafka-trigger-auth
  namespace: $NAMESPACE
spec:
  secretTargetRef:
  - parameter: sasl
    name: kafka-credentials
    key: sasl
EOF

echo "  ✅ TriggerAuthentication created"

echo ""
echo "✅ KEDA ScaledObjects deployed successfully"
echo ""
echo "🔍 Check scaling status:"
echo "  kubectl get scaledobjects -n $NAMESPACE"
echo "  kubectl get hpa -n $NAMESPACE"
