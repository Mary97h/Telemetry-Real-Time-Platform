#!/bin/bash
set -e

echo "Deploying Telemetry Platform to Kubernetes"
echo "=============================================="

# Check context
CONTEXT=$(kubectl config current-context)
echo "Current context: $CONTEXT"

if [[ "$CONTEXT" != "kind-telemetry-platform" ]]; then
  echo "Warning: Not using kind cluster. Continue? (y/n)"
  read -r response
  if [[ "$response" != "y" ]]; then
    echo "Deployment cancelled"
    exit 1
  fi
fi

# Deploy in order
echo ""
echo "1. Deploying Monitoring Stack..."
./scripts/deploy-monitoring.sh

echo ""
echo "2. Deploying Flink Applications..."
./scripts/deploy-flink-apps.sh

echo ""
echo "3. Deploying Control API..."
./scripts/deploy-control-api.sh

echo ""
echo "4. Configuring KEDA Autoscaling..."
./scripts/deploy-keda-scalers.sh

# Wait for all deployments
echo ""
echo "Waiting for all pods to be ready..."
kubectl wait --for=condition=ready pod --all -n telemetry-platform --timeout=300s || true

# Display status
echo ""
echo "Deployment complete!"
echo ""
echo "Pod Status:"
kubectl get pods -n telemetry-platform
echo ""
echo "Services:"
kubectl get svc -n telemetry-platform
echo ""
echo "Access Points:"
echo "  Control API:  kubectl port-forward -n telemetry-platform svc/control-api 8080:8080"
echo "  Flink UI:     kubectl port-forward -n telemetry-platform svc/flink-ingest-job-rest 8081:8081"
echo "  Grafana:      kubectl port-forward -n monitoring svc/grafana 3000:80"
echo ""
echo "Next: Run 'make loadgen' to start generating test data"
