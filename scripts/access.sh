#!/usr/bin/env bash


namespace="desafio-esig"
pids=()

cleanup() {
  echo
  echo "Encerrando os acessos..."

  for pid in "${pids[@]}"; do
    kill "$pid" > /dev/null 2>&1 || true
  done
}

trap cleanup EXIT INT TERM

if ! kubectl get namespace "$namespace" > /dev/null 2>&1; then
  echo "Erro: namespace '$namespace' não encontrado."
  echo "Implante o projeto antes de iniciar os acessos."
  exit 1
fi

echo "Iniciando acesso ao Jenkins..."

kubectl port-forward \
  -n "$namespace" \
  --address 127.0.0.1 \
  svc/jenkins \
  8080:8080 &

pids+=("$!")

echo "Iniciando acesso ao Prometheus..."

kubectl port-forward \
  -n "$namespace" \
  --address 127.0.0.1 \
  svc/prometheus \
  9090:9090 &

pids+=("$!")

echo "Iniciando acesso ao Grafana..."

kubectl port-forward \
  -n "$namespace" \
  --address 127.0.0.1 \
  svc/grafana \
  3000:3000 &

pids+=("$!")

sleep 2

for pid in "${pids[@]}"; do
  if ! kill -0 "$pid" > /dev/null 2>&1; then
    echo "Erro: não foi possível iniciar um dos acessos."
    echo "Verifique se as portas 8080, 9090 ou 3000 já estão ocupadas."
    exit 1
  fi
done

echo
echo "Acessos disponíveis:"
echo
echo "Jenkins:    http://127.0.0.1:8080/jenkins"
echo "Jolokia:    http://127.0.0.1:8080/jolokia"
echo "Prometheus: http://127.0.0.1:9090"
echo "Grafana:    http://127.0.0.1:3000"
echo

wait