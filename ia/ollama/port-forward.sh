#!/bin/bash
NAMESPACE="ollama-ns"
SERVICE="ollama-service"

if ! kubectl get svc -n "$NAMESPACE" "$SERVICE" &>/dev/null; then
    echo "Ollama não encontrado (namespace: $NAMESPACE)"
    exit 1
fi

pkill -f "port-forward -n $NAMESPACE" 2>/dev/null || true
kubectl port-forward -n "$NAMESPACE" "svc/$SERVICE" 11434:11434 > /dev/null 2>&1 &
echo "Ollama:     http://localhost:11434 (API REST)"
echo "            -> ollama pull llama3.2:1b   (baixar modelo)"
echo "            -> ollama run  llama3.2:1b   (executar modelo)"
