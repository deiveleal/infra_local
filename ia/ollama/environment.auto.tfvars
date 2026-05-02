namespace = "ollama-ns"

# Modelos para pré-baixar na inicialização.
# Atenção: cada modelo pode ocupar 1–8 GB e o download bloqueia o apply.
# Deixe vazio para gerenciar modelos manualmente via `ollama pull`.
models = ["phi3:latest"]
