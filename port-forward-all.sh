#!/bin/bash

echo "Limpando port-forwards antigos..."
pkill -f "kubectl port-forward" 2>/dev/null || true
sleep 1

echo ""
bash storage/minio/port-forward.sh
bash message/rabbitmq/port-forward.sh
bash message/kafka/port-forward.sh
bash database/mongodb/port-forward.sh
bash database/postgresql/port-forward.sh
bash vis/superset/port-forward.sh
bash ia/ollama/port-forward.sh
bash orquestrador/airflow/port-forward.sh
echo ""
echo "Para parar: make port-forward-stop"
