#!/usr/bin/env bash

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cd "$project_dir"

cluster_name="desafio-esig"
namespace="desafio-esig"
image_name="desafio-esig/jenkins-tomcat"

echo "Preparando os arquivos WAR..."

mkdir -p downloads

if [[ ! -f downloads/jenkins.war ]]; then
  curl -fL \
    https://get.jenkins.io/war-stable/2.568.2/jenkins.war \
    -o downloads/jenkins.war
fi

if [[ ! -f downloads/jolokia.war ]]; then
  curl -fL \
    https://repo1.maven.org/maven2/org/jolokia/jolokia-agent-war/2.6.1/jolokia-agent-war-2.6.1.war \
    -o downloads/jolokia.war
fi

if [[ ! -f kubernetes/jenkins/.env ]]; then
  echo "Erro: kubernetes/jenkins/.env não encontrado."
  exit 1
fi

if [[ ! -f kubernetes/grafana/.env ]]; then
  echo "Erro: kubernetes/grafana/.env não encontrado."
  exit 1
fi

echo "Construindo a imagem..."

docker build \
  -f docker/Dockerfile \
  -t "$image_name" \
  .

if kind get clusters | grep -qx "$cluster_name"; then
  echo "Reutilizando o cluster '$cluster_name'."
else
  echo "Criando o cluster '$cluster_name'..."

  kind create cluster \
    --name "$cluster_name" \
    --config kubernetes/cluster/kind.yaml \
    --wait 5m
fi

kubectl config use-context \
  "kind-$cluster_name" \
  > /dev/null

echo "Carregando a imagem no Kind..."

kind load docker-image \
  "$image_name" \
  --name "$cluster_name"

echo "Aplicando os manifestos..."

kubectl apply \
  -k kubernetes

echo "Atualizando o Jenkins com a imagem local..."

kubectl rollout restart deploy/jenkins \
  -n "$namespace"

echo "Aguardando os componentes..."

kubectl rollout status deploy/jenkins \
  -n "$namespace" \
  --timeout=5m

kubectl rollout status deploy/prometheus \
  -n "$namespace" \
  --timeout=3m

kubectl rollout status deploy/grafana \
  -n "$namespace" \
  --timeout=3m

kubectl rollout status daemonset/node-exporter \
  -n "$namespace" \
  --timeout=3m

echo
echo "Implantação concluída."
echo "Execute ./scripts/access.sh para acessar os serviços."