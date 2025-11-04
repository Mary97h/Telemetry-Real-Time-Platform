#!/bin/bash
set -e

echo "Validating Telemetry Platform Deployment"
echo "======================================="

NAMESPACE="telemetry-platform"
MONITORING_NS="monitoring"
KAFKA_NS="kafka"

ERRORS=0
WARNINGS=0

# Helper functions
check_pods() {
    local ns=$1
    local label=$2
    local expected=$3
    
    echo -n "  Checking $label pods in $ns... "
    local ready=$(kubectl get pods -n $ns -l $label -o json | jq -r '.items[] | select(.status.phase=="Running") | .metadata.name' | wc -l)
    
    if [ "$ready" -ge "$expected" ]; then
        echo "OK ($ready/$expected ready)"
    else
        echo "FAIL ($ready/$expected ready)"
        ((ERRORS++))
    fi
}

check_service() {
    local ns=$1
    local svc=$2
    
    echo -n "  Checking service $svc in $ns... "
    if kubectl get svc -n $ns $svc &>/dev/null; then
        echo "OK"
    else
        echo "ERROR"
        ((ERRORS++))
    fi
}

check_endpoint() {
    local url=$1
    local name=$2
    
    echo -n "  Checking $name ($url)... "
    if curl -sf "$url" >/dev/null 2>&1; then
        echo "OK"
    else
        echo "WARNING (not accessible)"
        ((WARNINGS++))
    fi
}

# Check Kubernetes cluster
echo ""
echo "1. Kubernetes Cluster"
echo -n "  Cluster reachable... "
if kubectl cluster-info &>/dev/null; then
    echo "OK"
else
    echo "ERROR"
    ((ERRORS++))
fi

echo -n "  Context: "
kubectl config current-context

# Check namespaces
echo ""
echo "2. Namespaces"
for ns in $NAMESPACE $MONITORING_NS $KAFKA_NS flink-operator keda; do
    echo -n "  $ns... "
    if kubectl get namespace $ns &>/dev/null; then
        echo "OK"
    else
        echo "ERROR"
        ((ERRORS++))
    fi
done

# Check operators
echo ""
echo "3. Operators"
check_pods "flink-operator" "app.kubernetes.io/name=flink-kubernetes-operator" 1
check_pods "kafka" "name=strimzi-cluster-operator" 1
check_pods "keda" "app=keda-operator" 1

# Check Flink deployments
echo ""
echo "4. Flink Applications"
echo -n "  FlinkDeployments... "
FLINK_JOBS=$(kubectl get flinkdeployment -n $NAMESPACE -o json | jq -r '.items | length')
if [ "$FLINK_JOBS" -ge 3 ]; then
    echo "OK ($FLINK_JOBS found)"
else
    echo "WARNING ($FLINK_JOBS found, expected 3)"
    ((WARNINGS++))
fi

check_pods $NAMESPACE "component=jobmanager" 3
check_pods $NAMESPACE "component=taskmanager" 6

# Check Control API
echo ""
echo "5. Control API"
check_pods $NAMESPACE "app=control-api" 2
check_service $NAMESPACE "control-api"

# Check monitoring
echo ""
echo "6. Monitoring Stack"
check_pods $MONITORING_NS "app.kubernetes.io/name=prometheus" 1
check_pods $MONITORING_NS "app.kubernetes.io/name=grafana" 1

# Check KEDA scaling
echo ""
echo "7. KEDA Autoscaling"
echo -n "  ScaledObjects... "
SCALED_OBJECTS=$(kubectl get scaledobject -n $NAMESPACE -o json | jq -r '.items | length')
if [ "$SCALED_OBJECTS" -ge 3 ]; then
    echo "OK ($SCALED_OBJECTS configured)"
else
    echo "WARNING ($SCALED_OBJECTS configured)"
    ((WARNINGS++))
fi

# Check Docker Compose services
echo ""
echo "8. External Services (Docker Compose)"
if command -v docker &>/dev/null; then
    check_endpoint "http://localhost:8081/subjects" "Schema Registry"
    check_endpoint "http://localhost:5432" "PostgreSQL"
    check_endpoint "http://localhost:6379" "Redis"
    check_endpoint "http://localhost:9090/-/healthy" "Prometheus (local)"
    check_endpoint "http://localhost:3000/api/health" "Grafana (local)"
else
    echo "  WARNING: Docker not available, skipping external service checks"
    ((WARNINGS++))
fi

# Check Kafka topics
echo ""
echo "9. Kafka Topics"
if docker ps | grep -q kafka-1; then
    echo -n "  Listing topics... "
    TOPICS=$(docker exec kafka-1 kafka-topics --bootstrap-server localhost:9092 --list 2>/dev/null | wc -l)
    if [ "$TOPICS" -ge 6 ]; then
        echo "OK ($TOPICS topics)"
    else
        echo "WARNING ($TOPICS topics, expected at least 6)"
        ((WARNINGS++))
    fi
    
    # Check specific topics
    for topic in telemetry.raw telemetry.enriched telemetry.aggregated telemetry.alerts control.commands control.feedback; do
        echo -n "    $topic... "
        if docker exec kafka-1 kafka-topics --bootstrap-server localhost:9092 --list 2>/dev/null | grep -q "^$topic$"; then
            echo "OK"
        else
            echo "ERROR"
            ((ERRORS++))
        fi
    done
else
    echo "  WARNING: Kafka not running, skipping topic checks"
    ((WARNINGS++))
fi

# Check metrics availability
echo ""
echo "10. Metrics & Observability"
echo -n "  Prometheus targets... "
echo "(manual check required)"

echo -n "  ServiceMonitors... "
SERVICE_MONITORS=$(kubectl get servicemonitor -n $NAMESPACE -o json | jq -r '.items | length' 2>/dev/null || echo "0")
if [ "$SERVICE_MONITORS" -ge 2 ]; then
    echo "OK ($SERVICE_MONITORS configured)"
else
    echo "WARNING ($SERVICE_MONITORS configured)"
    ((WARNINGS++))
fi

# Resource usage
echo ""
echo "11. Resource Usage"
echo "  Node resource utilization:"
kubectl top nodes 2>/dev/null || echo "    WARNING: Metrics not available (metrics-server may not be ready)"

echo ""
echo "  Pod resource usage (top 5):"
kubectl top pods -n $NAMESPACE --sort-by=cpu 2>/dev/null | head -n 6 || echo "    WARNING: Metrics not available"

# Summary
echo ""
echo "======================================="
echo "Validation Summary"
echo "======================================="

if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo "All checks passed!"
    echo ""
    echo "Platform is fully operational"
    exit 0
elif [ $ERRORS -eq 0 ]; then
    echo "Passed with $WARNINGS warning(s)"
    echo ""
    echo "Platform is operational with minor issues"
    exit 0
else
    echo "Failed with $ERRORS error(s) and $WARNINGS warning(s)"
    echo ""
    echo "Please review the errors above and redeploy components as needed"
    exit 1
fi
