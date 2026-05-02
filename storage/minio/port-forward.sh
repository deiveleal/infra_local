#!/bin/bash
NAMESPACE="minio-server-ns"
SERVICE="minio-service"

if ! kubectl get svc -n "$NAMESPACE" "$SERVICE" &>/dev/null; then
    echo "MinIO não encontrado (namespace: $NAMESPACE)"
    exit 1
fi

pkill -f "port-forward -n $NAMESPACE" 2>/dev/null || true
kubectl port-forward -n "$NAMESPACE" "svc/$SERVICE" 9000:9000 9001:9001 > /dev/null 2>&1 &
echo "MinIO:      http://localhost:9001 (UI) | localhost:9000 (API S3)"
