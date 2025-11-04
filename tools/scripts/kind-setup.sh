#!/bin/bash
set -e

echo "Creating kind cluster for Telemetry Platform"
echo "================================================"

# Check prerequisites
command -v kind >/dev/null 2>&1 || { echo "kind is required but not installed. Visit: https://kind.sigs.k8s.io/"; exit 1; }
command -v kubectl >/dev/null 2>&1 || { echo "kubectl is required but not installed."; exit 1; }
command -v helm >/dev/null 2>&1 || { echo "helm is required but not installed."; exit 1; }

# Create checkpoint directory
mkdir -p /tmp/flink-checkpoints
chmod 777 /tmp/flink-checkpoints

# Delete existing cluster if present
if kind get clusters | grep -q "telemetry-platform"; then
    echo "Deleting existing cluster..."
    kind delete cluster --name telemetry-platform
fi

# Create kind cluster
echo ""
echo "Creating kind cluster..."
kind create cluster --config kind-cluster.yaml --wait 5m

# Verify cluster
echo ""
echo "Cluster created successfully"
kubectl cluster-info --context kind-telemetry-platform

# Install Nginx Ingress Controller
echo ""
echo "Installing Nginx Ingress Controller..."
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

# Wait for ingress controller
echo "Waiting for ingress controller..."
kubectl wait --namespace ingress-nginx \
    --for=condition=ready pod \
    --selector=app.kubernetes.io/component=controller \
    --timeout=90s

# Install Metrics Server
echo ""
echo "Installing Metrics Server..."
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Patch metrics server for kind
kubectl patch deployment metrics-server -n kube-system --type='json' \
    -p='[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--kubelet-insecure-tls"}]'

# Create namespaces
echo ""
echo "Creating namespaces..."
kubectl create namespace telemetry-platform --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace kafka --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace flink-operator --dry-run=client -o yaml | kubectl apply -f -

# Label namespaces
kubectl label namespace telemetry-platform environment=local --overwrite
kubectl label namespace kafka environment=local --overwrite
kubectl label namespace monitoring environment=local --overwrite
kubectl label namespace flink-operator environment=local --overwrite

# Add Helm repositories
echo ""
echo "Adding Helm repositories..."
helm repo add flink-kubernetes-operator https://downloads.apache.org/flink/flink-kubernetes-operator-1.7.0/
helm repo add strimzi https://strimzi.io/charts/
helm repo add kedacore https://kedacore.github.io/charts
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

# Install Flink Kubernetes Operator
echo ""
echo "Installing Flink Kubernetes Operator..."
helm upgrade --install flink-kubernetes-operator flink-kubernetes-operator/flink-kubernetes-operator \
    --namespace flink-operator \
    --set webhook.create=true \
    --set metrics.port=9999 \
    --wait

# Install Strimzi Kafka Operator
echo ""
echo "Installing Strimzi Kafka Operator..."
helm upgrade --install strimzi-kafka strimzi/strimzi-kafka-operator \
    --namespace kafka \
    --set watchAnyNamespace=true \
    --wait

# Install KEDA
echo ""
echo "Installing KEDA..."
helm upgrade --install keda kedacore/keda \
    --namespace keda \
    --create-namespace \
    --set prometheus.metricServer.enabled=true \
    --wait

# Create secret for connecting to local docker-compose services
echo ""
echo "Creating configuration secrets..."
kubectl create secret generic kafka-config \
    --from-literal=bootstrap-servers=host.docker.internal:19092 \
    --namespace telemetry-platform \
    --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret generic postgres-config \
    --from-literal=host=host.docker.internal \
    --from-literal=port=5432 \
    --from-literal=database=telemetry \
    --from-literal=username=admin \
    --from-literal=password=telemetry-secret-2024 \
    --namespace telemetry-platform \
    --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret generic redis-config \
    --from-literal=host=host.docker.internal \
    --from-literal=port=6379 \
    --namespace telemetry-platform \
    --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret generic schema-registry-config \
    --from-literal=url=http://host.docker.internal:8081 \
    --namespace telemetry-platform \
    --dry-run=client -o yaml | kubectl apply -f -

# Display cluster info
echo ""
echo "Kind cluster setup complete!"
echo ""
echo "Cluster Information:"
kubectl get nodes -o wide
echo ""
echo "Namespaces:"
kubectl get namespaces --show-labels | grep -E "telemetry|kafka|monitoring|flink"
echo ""
echo "Installed Operators:"
kubectl get pods -n flink-operator
kubectl get pods -n kafka
kubectl get pods -n keda
echo ""
echo "Next: Run 'make deploy-all' to deploy the platform"
