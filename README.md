# Infraestrutura para teste local

Repositório base para subir ferramentas de infraestrutura localmente via Kubernetes, usando Terraform. Ideal para experimentos e desenvolvimento local.

## Ferramentas disponíveis

| Ferramenta | Categoria      | Porta(s)          | Interface Web          | Credenciais           |
|------------|----------------|-------------------|------------------------|-----------------------|
| MinIO      | Storage        | 9000 (API), 9001  | http://localhost:9001  | adminuser / adminuser |
| RabbitMQ   | Mensageria     | 5672, 15672       | http://localhost:15672 | adminuser / adminuser |
| Kafka      | Mensageria     | 9092              | —                      | sem autenticação      |
| MongoDB    | Banco NoSQL    | 27017             | —                      | adminuser / adminuser |
| PostgreSQL | Banco Relacional | 5432            | —                      | adminuser / adminuser |
| Ollama     | IA / LLM       | 11434             | —                      | sem autenticação      |

**Notas:**
- DB padrão do PostgreSQL: `eda-postgresql-db`
- MinIO inicializa com os buckets: `logs`, `staging`, `bronze`, `silver`, `gold`
- Kafka inicializa com os tópicos: `ingestion.database.events`, `pipeline.processed.data`, `system.logs`
- Ollama: modelos configurados em `ia/ollama/environment.auto.tfvars` (padrão: `phi3:latest`)
- Armazenamento via `hostPath` — dados persistem entre restarts do pod, mas são apagados com `kind delete cluster` / `minikube delete`

## Pré-requisitos

- [`kubectl`](https://kubernetes.io/docs/tasks/tools/) com um cluster local configurado
  - [kind](https://kind.sigs.k8s.io/) — recomendado
  - [minikube](https://minikube.sigs.k8s.io/)
  - Docker Desktop (Kubernetes integrado)
- [`terraform`](https://developer.hashicorp.com/terraform/install) ≥ 1.0
- [`helm`](https://helm.sh/docs/intro/install/) — necessário para o Kafka (usado via provider Terraform)

## Início rápido

```bash
# 1. Baixar os providers de todos os componentes
make init

# 2. Subir tudo e iniciar os port-forwards
make apply
```

## Subir ferramentas individualmente

```bash
make init kafka
make apply kafka

make init mongodb
make apply mongodb
```

Ferramentas disponíveis: `minio`, `rabbitmq`, `kafka`, `mongodb`, `postgresql`, `ollama`

É possível combinar múltiplas ferramentas em um único comando:

```bash
make apply mongodb postgresql
make destroy rabbitmq kafka
```

## Destruir

```bash
make destroy                    # destrói tudo (ordem reversa)
make destroy postgresql         # destrói apenas o PostgreSQL
make destroy mongodb postgresql # destrói os dois
```

## Port-forwards

```bash
make port-forward               # (re)inicia todos os port-forwards em background
make port-forward ollama        # port-forward apenas do Ollama
make port-forward-stop          # para todos
make port-forward-stop kafka    # para apenas o Kafka
```

## Testes

```bash
# Script shell — sem dependências, apenas curl/nc/kubectl
bash test_infra.sh

# Testes Python — CRUD completo em cada serviço
pip install -r test_requirements.txt
python test_infra.py
```

O script shell verifica conectividade, autenticação e estado dos recursos (topics, vhosts, modelos).
O script Python executa operações de leitura/escrita em cada serviço.
Ambos retornam exit code `0` se tudo passou, `1` se algum check falhou.

## Ollama — gerenciar modelos

Após subir o Ollama, os modelos são gerenciados via API ou CLI (requer port-forward ativo):

```bash
# Baixar um modelo
curl http://localhost:11434/api/pull -d '{"name":"llama3.2:1b"}'

# Listar modelos instalados
curl http://localhost:11434/api/tags

# Usar via ollama CLI (se instalado localmente)
OLLAMA_HOST=http://localhost:11434 ollama pull phi3:latest
OLLAMA_HOST=http://localhost:11434 ollama run  phi3:latest
```

Para pré-carregar modelos automaticamente no `apply`, edite `ia/ollama/environment.auto.tfvars`:

```hcl
models = ["phi3:latest", "llama3.2:1b"]
```

> **Atenção:** cada modelo ocupa 1–8 GB e o download bloqueia o `terraform apply` até concluir.

## Estrutura

```
infra_local/
├── database/
│   ├── mongodb/       — MongoDB 6.0
│   └── postgresql/    — PostgreSQL
├── ia/
│   └── ollama/        — Ollama (LLM local, CPU)
├── message/
│   ├── kafka/         — Kafka via Bitnami Helm (KRaft, sem Zookeeper)
│   └── rabbitmq/      — RabbitMQ 4 com management UI
├── storage/
│   └── minio/         — MinIO (buckets pré-criados no apply)
├── makefile
└── port-forward-all.sh
```

Cada ferramenta contém:
```
<ferramenta>/
├── main.tf                   — provider Terraform
├── variables.tf              — variáveis
├── environment.auto.tfvars   — valores padrão para dev local
├── <ferramenta>_server.tf    — recursos Kubernetes
└── port-forward.sh           — script de port-forward individual
```
