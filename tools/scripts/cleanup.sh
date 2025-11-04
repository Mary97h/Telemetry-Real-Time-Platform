#!/bin/bash

echo "Cleaning up Telemetry Platform"
echo "=================================="

# Confirm cleanup
read -p "This will delete all data and resources. Continue? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then
  echo "Cleanup cancelled"
  exit 0
fi

# Delete kind cluster
echo ""
echo "1) Deleting kind cluster..."
if kind get clusters | grep -q "telemetry-platform"; then
  kind delete cluster --name telemetry-platform
  echo "  Cluster deleted"
else
  echo "  No cluster found"
fi

# Stop Docker Compose
echo ""
echo "2) Stopping Docker Compose services..."
if [ -f "docker-compose.yml" ]; then
  docker-compose down -v
  echo "  Services stopped"
else
  echo "  No docker-compose.yml found"
fi

# Clean Docker resources
echo ""
echo "3) Cleaning Docker resources..."
read -p "Remove all telemetry-related images? (y/n): " clean_images
if [ "$clean_images" = "y" ]; then
  docker images | grep -E "flink|kafka|control-api" | awk '{print $3}' | xargs -r docker rmi -f || true
  echo "  Images removed"
fi

# Remove checkpoint directory
echo ""
echo "Removing checkpoint directory..."
if [ -d "/tmp/flink-checkpoints" ]; then
  rm -rf /tmp/flink-checkpoints
  echo "  Checkpoints removed"
fi

# Clean kubectl contexts
echo ""
echo "Cleaning kubectl contexts..."
kubectl config delete-context kind-telemetry-platform 2>/dev/null && echo "  Context removed" || echo "  No context found"
kubectl config delete-cluster kind-telemetry-platform 2>/dev/null || true

# Optional: Prune Docker system
echo ""
read -p "Run 'docker system prune -a' to free disk space? (y/n): " prune
if [ "$prune" = "y" ]; then
  docker system prune -a -f
  echo "  Docker system pruned"
fi

echo ""
echo "Cleanup complete!"
echo ""
echo "To start fresh, run:"
echo "  make docker-up && make kind-up && make deploy-all"
