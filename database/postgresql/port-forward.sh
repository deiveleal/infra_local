#!/bin/bash
NAMESPACE="postgresql-ns"
SERVICE="postgresql"

if ! kubectl get svc -n "$NAMESPACE" "$SERVICE" &>/dev/null; then
    echo "PostgreSQL não encontrado (namespace: $NAMESPACE)"
    exit 1
fi

pkill -f "port-forward -n $NAMESPACE" 2>/dev/null || true
kubectl port-forward -n "$NAMESPACE" "svc/$SERVICE" 5432:5432 > /dev/null 2>&1 &
echo "PostgreSQL: localhost:5432"
