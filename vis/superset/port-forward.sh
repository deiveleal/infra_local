#!/bin/bash
NAMESPACE="superset-ns"
SERVICE="superset-service"

if ! kubectl get svc -n "$NAMESPACE" "$SERVICE" &>/dev/null; then
    echo "Superset não encontrado (namespace: $NAMESPACE)"
    exit 1
fi

pkill -f "port-forward -n $NAMESPACE" 2>/dev/null || true
kubectl port-forward -n "$NAMESPACE" "svc/$SERVICE" 8088:8088 > /dev/null 2>&1 &
echo "Superset:   http://localhost:8088 (UI)"
