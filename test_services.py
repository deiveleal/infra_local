#!/usr/bin/env python3
"""
Testes de conectividade e funcionalidade para serviços de infraestrutura local.

Serviços cobertos
─────────────────
  MinIO      → upload / download / delete de objeto
  RabbitMQ   → conexão AMQP, management API, publish/consume
  Kafka      → lista de tópicos, produce, consume
  MongoDB    → ping, insert, find, cleanup
  PostgreSQL → conexão, insert, select, cleanup
  Ollama     → API, lista de modelos, inferência
  Airflow    → health, autenticação, listar DAGs

Instalação
──────────
  pip install minio pika kafka-python pymongo psycopg2-binary requests

Uso
───
  python test_services.py

Exit code: 0 = todos passaram  |  1 = algum falhou
"""

import io
import sys
import time
import uuid
from dataclasses import dataclass

# ══════════════════════════════════════════════════════════════════════════════
# CONFIGURAÇÃO — ajuste para o seu ambiente
# ══════════════════════════════════════════════════════════════════════════════

MINIO = {
    "endpoint":   "localhost:9000",
    "access_key": "adminuser",
    "secret_key": "adminuser",
    "secure":     False,
    "buckets":    ["logs", "staging", "bronze", "silver", "gold"],
    "test_bucket": "logs",
}

RABBITMQ = {
    "host":      "localhost",
    "amqp_port": 5672,
    "mgmt_port": 15672,
    "user":      "adminuser",
    "password":  "adminuser",
    "vhost":     "eda-vhost",
}

KAFKA = {
    "bootstrap_servers": ["localhost:9092"],
    "topics": [
        "ingestion.database.events",
        "pipeline.processed.data",
        "system.logs",
    ],
    "test_topic": "system.logs",
}

MONGODB = {
    "uri": "mongodb://adminuser:adminuser@localhost:27017/?authSource=admin",
    "timeout_ms": 5000,
}

POSTGRESQL = {
    "host":     "localhost",
    "port":     5432,
    "database": "eda-postgresql-db",
    "user":     "adminuser",
    "password": "adminuser",
}

OLLAMA = {
    "base_url":          "http://localhost:11434",
    "model":             "phi3:latest",
    "run_inference":     True,   # False → pula a inferência (mais rápido)
    "inference_timeout": 120,
}

AIRFLOW = {
    "base_url": "http://localhost:8080",
    "user":     "adminuser",
    "password": "adminuser",
}

# ══════════════════════════════════════════════════════════════════════════════
# Infraestrutura de resultados
# ══════════════════════════════════════════════════════════════════════════════

_GREEN  = "\033[32m"
_RED    = "\033[31m"
_CYAN   = "\033[36m"
_BOLD   = "\033[1m"
_RESET  = "\033[0m"

PASS_ICON = f"{_GREEN}✓{_RESET}"
FAIL_ICON = f"{_RED}✗{_RESET}"
SKIP_ICON = f"{_CYAN}~{_RESET}"


@dataclass
class Resultado:
    nome: str
    passou: bool
    detalhe: str = ""


_resultados: list[Resultado] = []


def rodar(nome: str, fn) -> bool:
    """Executa fn(), registra e imprime resultado."""
    try:
        detalhe = fn() or ""
        _resultados.append(Resultado(nome, passou=True, detalhe=str(detalhe)))
        sufixo = f"  {_CYAN}→ {detalhe}{_RESET}" if detalhe else ""
        print(f"  {PASS_ICON}  {nome}{sufixo}")
        return True
    except Exception as exc:
        _resultados.append(Resultado(nome, passou=False, detalhe=str(exc)))
        print(f"  {FAIL_ICON}  {nome}")
        print(f"       {_RED}{exc}{_RESET}")
        return False


def pular(nome: str, motivo: str) -> None:
    _resultados.append(Resultado(nome, passou=True, detalhe=f"SKIP: {motivo}"))
    print(f"  {SKIP_ICON}  {nome}  {_CYAN}({motivo}){_RESET}")


def secao(titulo: str) -> None:
    barra = "─" * max(0, 54 - len(titulo))
    print(f"\n── {titulo} {barra}")


# ══════════════════════════════════════════════════════════════════════════════
# MinIO
# ══════════════════════════════════════════════════════════════════════════════

def testar_minio() -> None:
    secao(f"MinIO  {MINIO['endpoint']}")
    try:
        from minio import Minio
    except ImportError:
        pular("MinIO", "pip install minio")
        return

    cfg    = MINIO
    client = Minio(cfg["endpoint"], access_key=cfg["access_key"],
                   secret_key=cfg["secret_key"], secure=cfg["secure"])

    bucket = cfg["test_bucket"]
    chave  = f"_teste/{uuid.uuid4().hex}.txt"
    dados  = b"infra-test"

    def listar_buckets():
        encontrados = {b.name for b in client.list_buckets()}
        esperados   = set(cfg["buckets"])
        ausentes    = esperados - encontrados
        if ausentes:
            raise AssertionError(f"buckets ausentes: {ausentes}")
        return f"{len(encontrados)} buckets OK"

    def upload():
        client.put_object(bucket, chave, io.BytesIO(dados), len(dados))
        return f"{bucket}/{chave.split('/')[-1]}"

    def download():
        resp     = client.get_object(bucket, chave)
        conteudo = resp.read()
        resp.close()
        if conteudo != dados:
            raise AssertionError(f"conteúdo divergente: {conteudo!r}")
        return f"{len(conteudo)} bytes verificados"

    def deletar():
        client.remove_object(bucket, chave)
        return "objeto removido"

    rodar("MinIO: listar buckets", listar_buckets)
    if rodar("MinIO: upload", upload):
        rodar("MinIO: download e verificação", download)
        rodar("MinIO: deletar objeto", deletar)


# ══════════════════════════════════════════════════════════════════════════════
# RabbitMQ
# ══════════════════════════════════════════════════════════════════════════════

def testar_rabbitmq() -> None:
    secao(f"RabbitMQ  AMQP {RABBITMQ['amqp_port']} | management {RABBITMQ['mgmt_port']}")
    try:
        import pika
        import requests as req
    except ImportError:
        pular("RabbitMQ", "pip install pika requests")
        return

    cfg = RABBITMQ

    def _conexao():
        return pika.BlockingConnection(pika.ConnectionParameters(
            host=cfg["host"], port=cfg["amqp_port"],
            virtual_host=cfg["vhost"],
            credentials=pika.PlainCredentials(cfg["user"], cfg["password"]),
            socket_timeout=5,
        ))

    def conexao_amqp():
        conn = _conexao()
        conn.close()
        return f"vhost '{cfg['vhost']}' acessível"

    def management_api():
        r = req.get(
            f"http://{cfg['host']}:{cfg['mgmt_port']}/api/health/checks/alarms",
            auth=(cfg["user"], cfg["password"]),
            timeout=5,
        )
        r.raise_for_status()
        return r.json().get("status", "ok")

    def publish_consume():
        corpo = f"teste-{uuid.uuid4().hex}".encode()
        conn  = _conexao()
        ch    = conn.channel()
        fila  = ch.queue_declare(queue="", exclusive=True, auto_delete=True).method.queue
        ch.basic_publish(exchange="", routing_key=fila, body=corpo)
        metodo, _, recebido = ch.basic_get(fila, auto_ack=True)
        conn.close()
        if metodo is None:
            raise AssertionError("mensagem não recebida")
        if recebido != corpo:
            raise AssertionError(f"conteúdo divergente: {recebido!r}")
        return f"{len(corpo)} bytes: publish → consume OK"

    rodar("RabbitMQ: conexão AMQP", conexao_amqp)
    rodar("RabbitMQ: management API", management_api)
    rodar("RabbitMQ: publish e consume", publish_consume)


# ══════════════════════════════════════════════════════════════════════════════
# Kafka
# ══════════════════════════════════════════════════════════════════════════════

def testar_kafka() -> None:
    secao(f"Kafka  {KAFKA['bootstrap_servers'][0]}")
    try:
        from kafka import KafkaAdminClient, KafkaProducer, KafkaConsumer
    except ImportError:
        pular("Kafka", "pip install kafka-python")
        return

    cfg    = KAFKA
    msg_id = uuid.uuid4().hex.encode()

    def listar_topicos():
        admin    = KafkaAdminClient(bootstrap_servers=cfg["bootstrap_servers"],
                                    request_timeout_ms=5000)
        topicos  = set(admin.list_topics())
        admin.close()
        ausentes = set(cfg["topics"]) - topicos
        if ausentes:
            raise AssertionError(f"tópicos ausentes: {ausentes}")
        return f"{len(topicos)} tópicos OK"

    def produce():
        producer = KafkaProducer(bootstrap_servers=cfg["bootstrap_servers"],
                                 request_timeout_ms=5000)
        future   = producer.send(cfg["test_topic"], value=msg_id)
        producer.flush(timeout=10)
        meta     = future.get(timeout=10)
        producer.close()
        return f"partição {meta.partition}, offset {meta.offset}"

    def consume():
        from kafka import TopicPartition

        consumer = KafkaConsumer(bootstrap_servers=cfg["bootstrap_servers"],
                                  enable_auto_commit=False)
        topic = cfg["test_topic"]
        partitions = consumer.partitions_for_topic(topic)
        if not partitions:
            consumer.close()
            raise AssertionError("nenhuma partição encontrada para o tópico")

        tps = [TopicPartition(topic, p) for p in partitions]
        consumer.assign(tps)
        consumer.seek_to_beginning(*tps)

        encontrado = False
        total_msgs = 0
        prazo = time.time() + 10
        while time.time() < prazo:
            batch = consumer.poll(timeout_ms=1000, max_records=200)
            for records in batch.values():
                for r in records:
                    total_msgs += 1
                    if r.value == msg_id:
                        encontrado = True
            if encontrado:
                break
        consumer.close()

        if not encontrado:
            raise AssertionError(
                f"mensagem produzida não encontrada ({total_msgs} msgs lidas)"
            )
        return f"{total_msgs} msgs lidas, mensagem de teste encontrada"

    rodar("Kafka: listar tópicos", listar_topicos)
    if rodar("Kafka: produce mensagem", produce):
        rodar("Kafka: consume e verificação", consume)


# ══════════════════════════════════════════════════════════════════════════════
# MongoDB
# ══════════════════════════════════════════════════════════════════════════════

def testar_mongodb() -> None:
    secao("MongoDB  localhost:27017")
    try:
        import pymongo
    except ImportError:
        pular("MongoDB", "pip install pymongo")
        return

    cfg      = MONGODB
    doc_id   = uuid.uuid4().hex
    db_teste = "_infra_test"
    client   = pymongo.MongoClient(cfg["uri"], serverSelectionTimeoutMS=cfg["timeout_ms"])

    def ping():
        client.admin.command("ping")
        return "pong"

    def inserir():
        col    = client[db_teste]["resultados"]
        result = col.insert_one({"_id": doc_id, "ts": time.time()})
        if not result.inserted_id:
            raise AssertionError("inserted_id ausente")
        return f"_id: {doc_id[:8]}…"

    def buscar():
        col = client[db_teste]["resultados"]
        doc = col.find_one({"_id": doc_id})
        if doc is None:
            raise AssertionError("documento não encontrado")
        return "documento recuperado com sucesso"

    def limpar():
        client.drop_database(db_teste)
        return f"database '{db_teste}' removido"

    rodar("MongoDB: ping", ping)
    if rodar("MongoDB: inserir documento", inserir):
        rodar("MongoDB: buscar documento", buscar)
    rodar("MongoDB: limpeza", limpar)


# ══════════════════════════════════════════════════════════════════════════════
# PostgreSQL
# ══════════════════════════════════════════════════════════════════════════════

def testar_postgresql() -> None:
    secao(f"PostgreSQL  {POSTGRESQL['host']}:{POSTGRESQL['port']}")
    try:
        import psycopg2
    except ImportError:
        pular("PostgreSQL", "pip install psycopg2-binary")
        return

    cfg   = POSTGRESQL
    tabela = f"_infra_test_{uuid.uuid4().hex[:8]}"
    valor  = uuid.uuid4().hex

    conn = psycopg2.connect(
        host=cfg["host"], port=cfg["port"], dbname=cfg["database"],
        user=cfg["user"], password=cfg["password"], connect_timeout=5,
    )
    conn.autocommit = True
    cur = conn.cursor()

    def versao():
        cur.execute("SELECT version()")
        return cur.fetchone()[0].split(",")[0]

    def criar_inserir():
        cur.execute(f"CREATE TABLE {tabela} (id SERIAL PRIMARY KEY, val TEXT NOT NULL)")
        cur.execute(f"INSERT INTO {tabela} (val) VALUES (%s)", (valor,))
        return f"tabela '{tabela}' criada e linha inserida"

    def selecionar():
        cur.execute(f"SELECT val FROM {tabela} LIMIT 1")
        linha = cur.fetchone()
        if linha is None or linha[0] != valor:
            raise AssertionError(f"esperado {valor!r}, obtido {linha!r}")
        return "valor verificado"

    def limpar():
        cur.execute(f"DROP TABLE IF EXISTS {tabela}")
        cur.close()
        conn.close()
        return f"tabela '{tabela}' removida"

    try:
        rodar("PostgreSQL: conexão e versão", versao)
        if rodar("PostgreSQL: criar tabela e inserir", criar_inserir):
            rodar("PostgreSQL: selecionar e verificar", selecionar)
        rodar("PostgreSQL: limpeza", limpar)
    except Exception:
        cur.close()
        conn.close()
        raise


# ══════════════════════════════════════════════════════════════════════════════
# Ollama
# ══════════════════════════════════════════════════════════════════════════════

def testar_ollama() -> None:
    secao(f"Ollama  {OLLAMA['base_url']}")
    try:
        import requests as req
    except ImportError:
        pular("Ollama", "pip install requests")
        return

    cfg  = OLLAMA
    base = cfg["base_url"]

    def api_acessivel():
        r = req.get(f"{base}/", timeout=5)
        r.raise_for_status()
        return "OK"

    def modelo_disponivel():
        r      = req.get(f"{base}/api/tags", timeout=5)
        r.raise_for_status()
        modelos = {m["name"] for m in r.json().get("models", [])}
        if cfg["model"] not in modelos:
            raise AssertionError(
                f"{cfg['model']!r} não encontrado; disponíveis: {modelos}"
            )
        return f"modelos: {', '.join(sorted(modelos))}"

    def inferencia():
        print(f"       {_CYAN}(executando {cfg['model']} — até {cfg['inference_timeout']}s){_RESET}")
        r = req.post(
            f"{base}/api/generate",
            json={
                "model":   cfg["model"],
                "prompt":  'Responda apenas com a palavra: "ok"',
                "stream":  False,
                "options": {"num_predict": 8},
            },
            timeout=cfg["inference_timeout"],
        )
        r.raise_for_status()
        resposta = r.json().get("response", "").strip()
        if not resposta:
            raise AssertionError("resposta vazia")
        return f'resposta: "{resposta}"'

    rodar("Ollama: API acessível", api_acessivel)
    modelo_ok = rodar(f"Ollama: modelo {cfg['model']} disponível", modelo_disponivel)
    if modelo_ok:
        if cfg["run_inference"]:
            rodar("Ollama: inferência end-to-end", inferencia)
        else:
            pular("Ollama: inferência end-to-end", "run_inference=False")


# ══════════════════════════════════════════════════════════════════════════════
# Airflow
# ══════════════════════════════════════════════════════════════════════════════

def testar_airflow() -> None:
    secao(f"Airflow  {AIRFLOW['base_url']}")
    try:
        import requests as req
    except ImportError:
        pular("Airflow", "pip install requests")
        return

    cfg  = AIRFLOW
    base = cfg["base_url"]
    auth = (cfg["user"], cfg["password"])

    def health():
        r = req.get(f"{base}/health", timeout=5)
        r.raise_for_status()
        data  = r.json()
        meta  = data.get("metadatabase", {}).get("status", "?")
        sched = data.get("scheduler",    {}).get("status", "?")
        if meta != "healthy":
            raise AssertionError(f"metadatabase={meta}")
        if sched != "healthy":
            raise AssertionError(f"scheduler={sched}")
        return f"metadatabase={meta}, scheduler={sched}"

    def autenticacao():
        r = req.get(f"{base}/api/v1/dags", auth=auth, timeout=5)
        if r.status_code == 401:
            raise AssertionError("credenciais inválidas")
        r.raise_for_status()
        return "básica OK"

    def listar_dags():
        r = req.get(f"{base}/api/v1/dags", auth=auth, params={"limit": 100}, timeout=5)
        r.raise_for_status()
        dags = r.json().get("dags", [])
        return f"{len(dags)} DAG(s) encontrada(s)"

    rodar("Airflow: health e componentes", health)
    if rodar("Airflow: autenticação", autenticacao):
        rodar("Airflow: listar DAGs", listar_dags)


# ══════════════════════════════════════════════════════════════════════════════
# Resumo final
# ══════════════════════════════════════════════════════════════════════════════

def resumo() -> bool:
    total  = len(_resultados)
    passou = sum(1 for r in _resultados if r.passou)
    falhou = total - passou
    pulou  = sum(1 for r in _resultados if r.detalhe.startswith("SKIP:"))

    linha = "═" * 56
    print(f"\n{linha}")
    if falhou == 0:
        print(f"  {_GREEN}{_BOLD}Todos os testes passaram{_RESET}  —  {passou}/{total}")
    else:
        print(f"  {_BOLD}{passou}/{total} passaram{_RESET}  —  {_RED}{_BOLD}{falhou} falharam{_RESET}")
        print(f"\n  Falhas:")
        for r in _resultados:
            if not r.passou:
                print(f"    {FAIL_ICON}  {r.nome}")
                if r.detalhe:
                    print(f"         {_RED}{r.detalhe}{_RESET}")
    if pulou:
        print(f"  {_CYAN}{pulou} pulados (pacotes não instalados){_RESET}")
    print(linha)
    return falhou == 0


# ══════════════════════════════════════════════════════════════════════════════
# Entry point
# ══════════════════════════════════════════════════════════════════════════════

if __name__ == "__main__":
    print(f"{_BOLD}Testes de infraestrutura local{_RESET}")
    print("Certifique-se de que os port-forwards estão ativos.\n")

    testar_minio()
    testar_rabbitmq()
    testar_kafka()
    testar_mongodb()
    testar_postgresql()
    testar_ollama()
    testar_airflow()

    sys.exit(0 if resumo() else 1)
