# infra_local/Makefile

# ── Tool paths & namespaces ───────────────────────────────────────────────────
PATH_minio      = storage/minio
PATH_rabbitmq   = message/rabbitmq
PATH_kafka      = message/kafka
PATH_mongodb    = database/mongodb
PATH_postgresql = database/postgresql
PATH_superset   = vis/superset
PATH_ollama     = ia/ollama
PATH_airflow    = orquestrador/airflow

NS_minio      = minio-server-ns
NS_rabbitmq   = rabbitmq-ns
NS_kafka      = kafka-ns
NS_mongodb    = mongodb-ns
NS_postgresql = postgresql-ns
NS_superset   = superset-ns
NS_ollama     = ollama-ns
NS_airflow    = airflow-ns

ALL_TOOLS     = minio rabbitmq kafka mongodb postgresql superset ollama airflow
APPLY_ORDER   = minio rabbitmq kafka mongodb postgresql superset ollama airflow
DESTROY_ORDER = airflow ollama superset postgresql mongodb kafka rabbitmq minio

.DEFAULT_GOAL := help

# Se um nome de ferramenta aparece nos goals, aplica só ela(s). Caso contrário, todas.
_SELECTED             = $(filter $(ALL_TOOLS),$(MAKECMDGOALS))
TOOLS                 = $(if $(_SELECTED),$(_SELECTED),$(ALL_TOOLS))
ORDERED_TOOLS         = $(foreach t,$(APPLY_ORDER),$(filter $(t),$(TOOLS)))
ORDERED_TOOLS_REVERSE = $(foreach t,$(DESTROY_ORDER),$(filter $(t),$(TOOLS)))

.PHONY: help init apply destroy port-forward port-forward-stop $(ALL_TOOLS)

# Ferramentas são alvos no-op — sua presença em MAKECMDGOALS é o que filtra a execução
$(ALL_TOOLS):
	@true

# ── Help ──────────────────────────────────────────────────────────────────────
help:
	@echo "infra_local — ambiente local de experimentos"
	@echo ""
	@echo "Ferramentas: $(ALL_TOOLS)"
	@echo ""
	@echo "Todas as ferramentas:"
	@echo "  make init"
	@echo "  make apply"
	@echo "  make destroy"
	@echo "  make port-forward"
	@echo "  make port-forward-stop"
	@echo ""
	@echo "Ferramenta específica:"
	@echo "  make init <ferramenta>"
	@echo "  make apply <ferramenta>"
	@echo "  make destroy <ferramenta>"
	@echo "  make port-forward <ferramenta>"
	@echo "  make port-forward-stop <ferramenta>"

# ── Init ──────────────────────────────────────────────────────────────────────
init:
	@for comp in $(foreach t,$(ORDERED_TOOLS),$(PATH_$(t))); do \
		echo "=== Init: $$comp ==="; \
		(cd $$comp && terraform init); \
	done

# ── Apply ─────────────────────────────────────────────────────────────────────
apply:
	@for comp in $(foreach t,$(ORDERED_TOOLS),$(PATH_$(t))); do \
		echo "=== Apply: $$comp ==="; \
		(cd $$comp && terraform apply -auto-approve); \
	done
	@echo ""
	@echo "Aguardando serviços ficarem prontos..."
	@sleep 5
	@for script in $(foreach t,$(ORDERED_TOOLS),$(PATH_$(t))/port-forward.sh); do \
		bash $$script; \
	done

# ── Destroy ───────────────────────────────────────────────────────────────────
destroy:
	@for comp in $(foreach t,$(ORDERED_TOOLS_REVERSE),$(PATH_$(t))); do \
		echo "=== Destroy: $$comp ==="; \
		(cd $$comp && terraform destroy -auto-approve); \
	done

# ── Port-forward ──────────────────────────────────────────────────────────────
port-forward:
	@for script in $(foreach t,$(ORDERED_TOOLS),$(PATH_$(t))/port-forward.sh); do \
		bash $$script; \
	done

port-forward-stop:
	@$(foreach t,$(ORDERED_TOOLS),pkill -f "port-forward -n $(NS_$(t))" || true;)
	@echo "Port-forwards parados"
