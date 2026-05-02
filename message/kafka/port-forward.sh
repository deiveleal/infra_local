#!/bin/bash
NAMESPACE="kafka-ns"
SERVICE="kafka"

if ! kubectl get svc -n "$NAMESPACE" "$SERVICE" &>/dev/null; then
    echo "Kafka não encontrado (namespace: $NAMESPACE)"
    exit 1
fi

pkill -f "port-forward -n $NAMESPACE" 2>/dev/null || true
# Mapa localhost:9092 → pod:9094 (listener EXTERNAL, que anuncia localhost:9092)
kubectl port-forward -n "$NAMESPACE" "svc/$SERVICE" 9092:9094 > /dev/null 2>&1 &
echo "Kafka:      localhost:9092 (bootstrap)"
