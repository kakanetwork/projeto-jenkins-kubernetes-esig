#!/usr/bin/env bash

set -euo pipefail

namespace="desafio-esig"
expected_context="kind-desafio-esig"
infra_pod="teste-carga-infra"

show_help() {
  cat <<'EOF'
Uso:
  ./test/teste_carga.sh infra [segundos]
  ./test/teste_carga.sh stop

Modos:
  infra  Cria um Pod temporario que aumenta o uso de CPU de um no.
  stop   Remove o Pod temporario do teste de infraestrutura.

Exemplos:
  ./test/teste_carga.sh infra 300
  ./test/teste_carga.sh stop
EOF
}

require_command() {
  if ! command -v "$1" > /dev/null 2>&1; then
    echo "Erro: o comando '$1' nao foi encontrado."
    exit 1
  fi
}

check_context() {
  local current_context
  current_context="$(kubectl config current-context)"

  if [[ "$current_context" != "$expected_context" ]]; then
    echo "Erro: contexto atual '$current_context'."
    echo "Use o contexto '$expected_context' antes de executar este teste."
    exit 1
  fi
}

validate_duration() {
  local duration="$1"

  if [[ ! "$duration" =~ ^[0-9]+$ ]] \
    || [[ "$duration" -lt 30 ]] \
    || [[ "$duration" -gt 900 ]]
  then
    echo "Erro: informe uma duracao entre 30 e 900 segundos."
    exit 1
  fi
}

run_infra_test() {
  local duration="${1:-300}"
  local node

  validate_duration "$duration"
  require_command kubectl
  check_context

  if kubectl get pod "$infra_pod" \
    -n "$namespace" \
    > /dev/null 2>&1
  then
    echo "Erro: o Pod '$infra_pod' ja existe."
    echo "Execute './test/teste_carga.sh stop' antes de iniciar outro teste."
    exit 1
  fi

  echo "Criando carga de CPU durante $duration segundos..."

  kubectl run "$infra_pod" \
    -n "$namespace" \
    --image=alpine:3.22 \
    --restart=Never \
    --command -- \
    sh -c "
      end=\$((\$(date +%s) + $duration))
      workers=\$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 12)

      i=0

      while [ \"\$i\" -lt \"\$workers\" ]; do
        while [ \"\$(date +%s)\" -lt \"\$end\" ]; do
          :
        done &

        i=\$((i + 1))
      done

      wait
    "

  kubectl wait \
    -n "$namespace" \
    --for=condition=Ready \
    "pod/$infra_pod" \
    --timeout=2m

  node="$(
    kubectl get pod "$infra_pod" \
      -n "$namespace" \
      -o jsonpath='{.spec.nodeName}'
  )"

  echo "Teste iniciado no no: $node"
  echo "Acompanhe o dashboard de infraestrutura no Grafana."
  echo "O Pod terminara sozinho; use o modo 'stop' para remove-lo antes."
}

stop_infra_test() {
  require_command kubectl
  check_context

  kubectl delete pod "$infra_pod" \
    -n "$namespace" \
    --ignore-not-found
}

mode="${1:-}"

case "$mode" in
  infra)
    run_infra_test "${2:-300}"
    ;;

  stop)
    stop_infra_test
    ;;

  -h|--help|help)
    show_help
    ;;

  *)
    show_help
    exit 1
    ;;
esac