#!/bin/bash
NAMESPACE="rabbitmq-ns"
SERVICE="rabbitmq-service"

if ! kubectl get svc -n "$NAMESPACE" "$SERVICE" &>/dev/null; then
    echo "RabbitMQ não encontrado (namespace: $NAMESPACE)"
    exit 1
fi

pkill -f "port-forward -n $NAMESPACE" 2>/dev/null || true
kubectl port-forward -n "$NAMESPACE" "svc/$SERVICE" 5672:5672 15672:15672 > /dev/null 2>&1 &
echo "RabbitMQ:   http://localhost:15672 (UI) | localhost:5672 (AMQP)"
