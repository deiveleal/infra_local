#!/bin/bash
NAMESPACE="airflow-ns"
SERVICE="airflow-service"

if ! kubectl get svc -n "$NAMESPACE" "$SERVICE" &>/dev/null; then
    echo "Airflow não encontrado (namespace: $NAMESPACE)"
    exit 1
fi

pkill -f "port-forward -n $NAMESPACE" 2>/dev/null || true
kubectl port-forward -n "$NAMESPACE" "svc/$SERVICE" 8080:8080 > /dev/null 2>&1 &
echo "Airflow:    http://localhost:8080 (Web UI)"
echo "Airflow:    http://localhost:8080/api/v1/ (API REST)"

