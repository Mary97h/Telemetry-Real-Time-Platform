#!/bin/bash
set -e

echo "Deploying Control API"

NAMESPACE="telemetry-platform"

# Build Control API Docker image (if needed)
if [ -d "apps/control-api" ]; then
  echo "Building Control API..."
  # In real scenario, would build and push to registry
  # cd apps/control-api && docker build -t control-api:latest .
  # kind load docker-image control-api:latest --name telemetry-platform
  echo "Skipping build (using Node.js base image in demo)"
fi

# Create ConfigMap for Control API
echo ""
echo "Creating Control API ConfigMap..."
kubectl create configmap control-api-config \
  --from-literal=KAFKA_BOOTSTRAP_SERVERS=host.docker.internal:19092 \
  --from-literal=POSTGRES_HOST=host.docker.internal \
  --from-literal=POSTGRES_PORT=5432 \
  --from-literal=POSTGRES_DB=telemetry \
  --from-literal=POSTGRES_USER=admin \
  --from-literal=REDIS_HOST=host.docker.internal \
  --from-literal=REDIS_PORT=6379 \
  --from-literal=LOG_LEVEL=info \
  --namespace $NAMESPACE \
  --dry-run=client -o yaml | kubectl apply -f -

# Create Control API deployment
echo ""
echo "Deploying Control API..."
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: control-api
  namespace: $NAMESPACE
  labels:
    app: control-api
spec:
  replicas: 2
  selector:
    matchLabels:
      app: control-api
  template:
    metadata:
      labels:
        app: control-api
    spec:
      containers:
      - name: control-api
        image: node:18-alpine
        command: ["/bin/sh"]
        args:
          - -c
          - |
            echo "Control API starting..."
            echo "Kafka: \$KAFKA_BOOTSTRAP_SERVERS"
            echo "PostgreSQL: \$POSTGRES_HOST:\$POSTGRES_PORT"
            echo "Redis: \$REDIS_HOST:\$REDIS_PORT"
            # Placeholder - would run actual Node.js server
            tail -f /dev/null
        ports:
        - containerPort: 8080
          name: http
        - containerPort: 9090
          name: grpc
        envFrom:
        - configMapRef:
            name: control-api-config
        - secretRef:
            name: postgres-config
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
        livenessProbe:
          exec:
            command:
            - /bin/sh
            - -c
            - "echo 'alive'"
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          exec:
            command:
            - /bin/sh
            - -c
            - "echo 'ready'"
          initialDelaySeconds: 10
          periodSeconds: 5
---
apiVersion: v1
kind: Service
metadata:
  name: control-api
  namespace: $NAMESPACE
  labels:
    app: control-api
spec:
  type: NodePort
  ports:
  - port: 8080
    targetPort: 8080
    nodePort: 30080
    name: http
  - port: 9090
    targetPort: 9090
    name: grpc
  selector:
    app: control-api
---
apiVersion: v1
kind: Service
metadata:
  name: control-api-metrics
  namespace: $NAMESPACE
  labels:
    app: control-api
spec:
  ports:
  - port: 9091
    targetPort: 9091
    name: metrics
  selector:
    app: control-api
EOF

# Wait for deployment
echo ""
echo "Waiting for Control API to be ready..."
kubectl rollout status deployment/control-api -n $NAMESPACE --timeout=120s

echo ""
echo "Control API deployed successfully"
echo ""
echo "Check status:"
echo "  kubectl get pods -n $NAMESPACE -l app=control-api"
echo ""
echo "Access API:"
echo "  kubectl port-forward -n $NAMESPACE svc/control-api 8080:8080"
echo "  curl http://localhost:8080/api/v1/health"
