#!/usr/bin/env bash

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cd "$project_dir"

namespace="desafio-esig"
expected_context="kind-desafio-esig"

jenkins_url="http://127.0.0.1:8080"
prometheus_url="http://127.0.0.1:9090"
grafana_url="http://127.0.0.1:3000"

echo "Verificando contexto do Kubernetes..."

current_context="$(kubectl config current-context)"

if [[ "$current_context" != "$expected_context" ]]; then
  echo "Erro: contexto atual é '$current_context'."
  echo "Esperado: '$expected_context'."
  exit 1
fi

echo "OK: contexto Kubernetes correto."
echo
echo "Verificando os componentes Kubernetes..."

kubectl rollout status deploy/jenkins \
  -n "$namespace" \
  --timeout=2m

kubectl rollout status deploy/prometheus \
  -n "$namespace" \
  --timeout=2m

kubectl rollout status deploy/grafana \
  -n "$namespace" \
  --timeout=2m

kubectl rollout status daemonset/node-exporter \
  -n "$namespace" \
  --timeout=2m

echo "OK: todos os componentes estão disponíveis."

echo
echo "Verificando volumes persistentes..."

if kubectl get pvc \
  -n "$namespace" \
  --no-headers \
  | awk '$2 != "Bound" { exit 1 }'
then
  echo "OK: todos os volumes estão vinculados."
else
  echo "Erro: existe volume sem estado Bound."
  exit 1
fi

echo
echo "Verificando Jenkins..."

curl -fsS \
  -o /dev/null \
  "$jenkins_url/jenkins/login"

echo "OK: Jenkins respondeu."

echo
echo "Verificando proteção do Jolokia..."

unauthenticated_code="$(
  curl -sS \
    -o /dev/null \
    -w '%{http_code}' \
    "$jenkins_url/jolokia/version"
)"

if [[ "$unauthenticated_code" != "401" ]]; then
  echo "Erro: Jolokia sem autenticação retornou HTTP $unauthenticated_code."
  exit 1
fi

echo "OK: Jolokia recusou acesso sem credenciais."

jolokia_user="$(
  grep '^JOLOKIA_USER=' kubernetes/jenkins/.env \
    | cut -d= -f2-
)"

jolokia_password="$(
  grep '^JOLOKIA_PASSWORD=' kubernetes/jenkins/.env \
    | cut -d= -f2-
)"

authenticated_code="$(
  curl -sS \
    -u "$jolokia_user:$jolokia_password" \
    -o /dev/null \
    -w '%{http_code}' \
    "$jenkins_url/jolokia/version"
)"

if [[ "$authenticated_code" != "200" ]]; then
  echo "Erro: Jolokia autenticado retornou HTTP $authenticated_code."
  exit 1
fi

echo "OK: Jolokia aceitou as credenciais."

echo
echo "Verificando Prometheus..."

curl -fsS \
  "$prometheus_url/-/healthy" \
  > /dev/null

echo "OK: Prometheus está saudável."

jvm_metrics="$(
  curl -fsS \
    -G "$prometheus_url/api/v1/query" \
    --data-urlencode \
    'query=tomcat_jvm_runtime_Uptime{job="jenkins-tomcat"}' \
  | jq -r '.data.result | length'
)"

if [[ "$jvm_metrics" -lt 1 ]]; then
  echo "Erro: métrica da JVM não encontrada."
  exit 1
fi

echo "OK: métricas da JVM estão disponíveis."

node_targets="$(
  curl -fsS \
    -G "$prometheus_url/api/v1/query" \
    --data-urlencode \
    'query=count(up{job="node-exporter"} == 1)' \
  | jq -r '.data.result[0].value[1] // "0"' \
  | cut -d. -f1
)"

if [[ "$node_targets" -ne 3 ]]; then
  echo "Erro: esperados 3 Node Exporters ativos, encontrados $node_targets."
  exit 1
fi

echo "OK: os 3 Node Exporters estão ativos."

echo
echo "Verificando Grafana..."

grafana_database="$(
  curl -fsS \
    "$grafana_url/api/health" \
  | jq -r '.database'
)"

if [[ "$grafana_database" != "ok" ]]; then
  echo "Erro: banco do Grafana retornou '$grafana_database'."
  exit 1
fi

echo "OK: Grafana está saudável."

echo
echo "Verificando provisionamento..."

kubectl get configmap \
  -n "$namespace" \
  -o name \
  | grep -q 'grafana-dashboards-'

echo "OK: dashboards provisionados."

kubectl get configmap \
  -n "$namespace" \
  -o name \
  | grep -q 'grafana-alert-rules-'

echo "OK: regras de alerta provisionadas."

echo
echo "Todos os testes foram concluídos com sucesso."