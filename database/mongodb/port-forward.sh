#!/bin/bash
NAMESPACE="mongodb-ns"
SERVICE="mongodb"

if ! kubectl get svc -n "$NAMESPACE" "$SERVICE" &>/dev/null; then
    echo "MongoDB não encontrado (namespace: $NAMESPACE)"
    exit 1
fi

pkill -f "port-forward -n $NAMESPACE" 2>/dev/null || true
kubectl port-forward -n "$NAMESPACE" "svc/$SERVICE" 27017:27017 > /dev/null 2>&1 &
echo "MongoDB:    localhost:27017"
