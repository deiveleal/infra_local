#!/bin/bash
# test_infra.sh — connectivity and health checks for all local infra services
# Requires active port-forwards: make port-forward
set -euo pipefail

# ── Colours ───────────────────────────────────────────────────────────────────
GREEN='\033[0;32m'; RED='\033[0;31m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'
PASS_ICON="${GREEN}✓${NC}"; FAIL_ICON="${RED}✗${NC}"; SKIP_ICON="${CYAN}~${NC}"

# ── Counters ──────────────────────────────────────────────────────────────────
PASS=0; FAIL=0; SKIP=0

pass() { printf "  ${PASS_ICON}  %s\n" "$1"; PASS=$((PASS + 1)); }
fail() { printf "  ${FAIL_ICON}  %s\n" "$1"; FAIL=$((FAIL + 1)); }
skip() { printf "  ${SKIP_ICON}  %s\n" "$1"; SKIP=$((SKIP + 1)); }

section() {
  local title="$1"
  local bar; bar=$(printf '─%.0s' $(seq 1 $((52 - ${#title}))))
  printf "\n── %s %s\n" "$title" "$bar"
}

# ── Helpers ───────────────────────────────────────────────────────────────────
port_open() { nc -z -w3 localhost "$1" 2>/dev/null; }

http_status() {
  curl -s -o /dev/null -w "%{http_code}" --max-time 5 "$@"
}

require_port() {
  local port=$1 label=$2
  if ! port_open "$port"; then
    fail "$label: port $port not reachable — is port-forward active? (make port-forward)"
    return 1
  fi
  return 0
}

# ── MinIO — localhost:9000 ─────────────────────────────────────────────────────
section "MinIO  localhost:9000 | console localhost:9001"

if require_port 9000 "MinIO"; then
  pass "port 9000 open"

  code=$(http_status http://localhost:9000/minio/health/live)
  [[ "$code" == "200" ]] && pass "health/live → $code" || fail "health/live → $code"

  code=$(http_status http://localhost:9000/minio/health/ready)
  [[ "$code" == "200" ]] && pass "health/ready → $code" || fail "health/ready → $code"

  # S3 root returns 403 for unsigned requests — confirms service is up and responding
  code=$(http_status http://localhost:9000/)
  [[ "$code" =~ ^(200|403)$ ]] && pass "S3 API responding (HTTP $code)" \
                                || fail "S3 API → unexpected HTTP $code (expected 200 or 403)"

  # Console
  if port_open 9001; then
    pass "port 9001 open (console)"
  else
    fail "port 9001 not reachable"
  fi
fi

# ── RabbitMQ — localhost:5672 | management localhost:15672 ────────────────────
section "RabbitMQ  localhost:5672 | management localhost:15672"

if require_port 5672 "RabbitMQ AMQP"; then
  pass "port 5672 open (AMQP)"
fi

if require_port 15672 "RabbitMQ management"; then
  pass "port 15672 open (management UI)"

  code=$(http_status -u adminuser:adminuser \
         http://localhost:15672/api/health/checks/alarms)
  [[ "$code" == "200" ]] && pass "management API auth OK" \
                          || fail "management API → HTTP $code (expected 200)"

  code=$(http_status -u adminuser:adminuser \
         "http://localhost:15672/api/vhosts/eda-vhost")
  [[ "$code" == "200" ]] && pass "vhost 'eda-vhost' exists" \
                          || fail "vhost 'eda-vhost' → HTTP $code"

  # Count queues in the vhost
  queue_count=$(curl -s --max-time 5 -u adminuser:adminuser \
    "http://localhost:15672/api/queues/eda-vhost" 2>/dev/null \
    | python3 -c "import sys,json; print(len(json.load(sys.stdin)))" 2>/dev/null || echo "?")
  pass "queues in eda-vhost: $queue_count"
fi

# ── Kafka — localhost:9092 ─────────────────────────────────────────────────────
section "Kafka  localhost:9092"

if require_port 9092 "Kafka"; then
  pass "port 9092 open (EXTERNAL listener)"

  # List topics by exec-ing into the pod (no kafka CLI needed on host)
  if kubectl get deploy kafka -n kafka-ns &>/dev/null 2>&1; then
    topics=$(kubectl exec -n kafka-ns deploy/kafka -- \
               /opt/kafka/bin/kafka-topics.sh \
               --bootstrap-server localhost:9092 --list 2>/dev/null || echo "")

    if [[ -n "$topics" ]]; then
      topic_count=$(echo "$topics" | wc -l | tr -d ' ')
      pass "topics via kubectl exec: $topic_count found"

      for expected in "ingestion.database.events" "pipeline.processed.data" "system.logs"; do
        echo "$topics" | grep -q "^${expected}$" \
          && pass "topic '$expected' exists" \
          || fail "topic '$expected' missing"
      done
    else
      fail "no topics found or broker unreachable"
    fi
  else
    skip "kubectl: kafka deployment not found — skipping topic check"
  fi
fi

# ── MongoDB — localhost:27017 ──────────────────────────────────────────────────
section "MongoDB  localhost:27017"

if require_port 27017 "MongoDB"; then
  pass "port 27017 open"

  if python3 -c "import pymongo" 2>/dev/null; then
    result=$(python3 - <<'PY' 2>/dev/null
import pymongo
try:
    c = pymongo.MongoClient(
        "mongodb://adminuser:adminuser@localhost:27017/?authSource=admin",
        serverSelectionTimeoutMS=3000
    )
    c.admin.command("ping")
    dbs = [d for d in c.list_database_names() if d not in ("admin","config","local")]
    print("ok:" + ",".join(dbs) if dbs else "ok:empty")
except Exception as e:
    print("err:" + str(e))
PY
)
    if [[ "$result" == ok* ]]; then
      info="${result#ok:}"
      [[ -n "$info" && "$info" != "empty" ]] \
        && pass "authenticated ping OK — user databases: $info" \
        || pass "authenticated ping OK (no user databases yet)"
    else
      fail "auth failed: ${result#err:}"
    fi
  else
    skip "pymongo not installed — port open but auth not verified (pip install pymongo)"
  fi
fi

# ── PostgreSQL — localhost:5432 ────────────────────────────────────────────────
section "PostgreSQL  localhost:5432"

if require_port 5432 "PostgreSQL"; then
  pass "port 5432 open"

  if python3 -c "import psycopg2" 2>/dev/null; then
    result=$(python3 - <<'PY' 2>/dev/null
import psycopg2
try:
    conn = psycopg2.connect(
        "host=localhost port=5432 dbname=eda-postgresql-db "
        "user=adminuser password=adminuser connect_timeout=3"
    )
    cur = conn.cursor()
    cur.execute("SELECT current_database(), version()")
    db, ver = cur.fetchone()
    conn.close()
    print("ok:" + db + "|" + ver.split()[0] + " " + ver.split()[1])
except Exception as e:
    print("err:" + str(e))
PY
)
    if [[ "$result" == ok* ]]; then
      info="${result#ok:}"
      db="${info%%|*}"; ver="${info##*|}"
      pass "connected to '$db' — $ver"
    else
      fail "connection failed: ${result#err:}"
    fi
  else
    skip "psycopg2 not installed — port open but auth not verified (pip install psycopg2-binary)"
  fi
fi

# ── Ollama — localhost:11434 ───────────────────────────────────────────────────
section "Ollama  localhost:11434"

if require_port 11434 "Ollama"; then
  pass "port 11434 open"

  code=$(http_status http://localhost:11434/)
  [[ "$code" == "200" ]] && pass "API reachable" || fail "API → HTTP $code"

  models=$(curl -s --max-time 5 http://localhost:11434/api/tags 2>/dev/null \
    | python3 -c "
import sys, json
data = json.load(sys.stdin)
names = [m['name'] for m in data.get('models', [])]
print(','.join(names) if names else '')
" 2>/dev/null || echo "")

  if [[ -n "$models" ]]; then
    pass "models loaded: $models"
  else
    fail "no models found — pull a model first: curl http://localhost:11434/api/pull -d '{\"name\":\"phi3:latest\"}'"
  fi
fi

# ── Airflow — localhost:8080 ───────────────────────────────────────────────────
section "Airflow  localhost:8080"

if require_port 8080 "Airflow"; then
  pass "port 8080 open"

  code=$(http_status http://localhost:8080/health)
  if [[ "$code" == "200" ]]; then
    pass "health endpoint → $code"

    health=$(curl -s --max-time 5 http://localhost:8080/health 2>/dev/null)
    meta=$(echo "$health" | python3 -c \
      "import sys,json; print(json.load(sys.stdin).get('metadatabase',{}).get('status','?'))" 2>/dev/null || echo "?")
    sched=$(echo "$health" | python3 -c \
      "import sys,json; print(json.load(sys.stdin).get('scheduler',{}).get('status','?'))" 2>/dev/null || echo "?")
    [[ "$meta"  == "healthy" ]] && pass "metadatabase: $meta"  || fail "metadatabase: $meta"
    [[ "$sched" == "healthy" ]] && pass "scheduler: $sched"    || fail "scheduler: $sched"
  else
    fail "health endpoint → $code"
  fi

  code=$(http_status -u adminuser:adminuser "http://localhost:8080/api/v1/dags?limit=100")
  if [[ "$code" == "200" ]]; then
    dag_count=$(curl -s --max-time 5 -u adminuser:adminuser \
      "http://localhost:8080/api/v1/dags?limit=100" 2>/dev/null \
      | python3 -c "import sys,json; print(len(json.load(sys.stdin).get('dags',[])))" 2>/dev/null || echo "?")
    pass "API autenticada OK — $dag_count DAG(s) encontrada(s)"
  else
    fail "API autenticada → HTTP $code (expected 200)"
  fi
fi

# ── Summary ────────────────────────────────────────────────────────────────────
TOTAL=$((PASS + FAIL + SKIP))
printf "\n%s\n" "$(printf '═%.0s' $(seq 1 56))"
if [[ $FAIL -eq 0 ]]; then
  printf "  ${GREEN}${BOLD}All checks passed${NC} — $PASS/$TOTAL passed"
  [[ $SKIP -gt 0 ]] && printf ", $SKIP skipped"
  printf "\n"
else
  printf "  ${BOLD}$PASS/$TOTAL passed${NC} — ${RED}${BOLD}$FAIL failed${NC}"
  [[ $SKIP -gt 0 ]] && printf ", $SKIP skipped"
  printf "\n"
fi
printf "%s\n" "$(printf '═%.0s' $(seq 1 56))"

[[ $FAIL -eq 0 ]]
