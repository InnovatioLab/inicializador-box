#!/bin/bash
#
# Roda setup_dev_machine.sh dentro de um container Ubuntu isolado.
# Útil se você não quiser instalar Multipass. Ambiente descartável (--rm).
#
# Limitação: dentro do container não há systemd completo; o script pode falhar
# em "systemctl start docker" ou em etapas que dependem de serviço. Use para
# testar sintaxe, repositórios e lógica inicial. Para teste completo, use
# test_run_multipass.sh.
#
# Pré-requisito: Docker instalado
#
# Uso: ./test_run_docker.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Iniciando container Ubuntu e rodando o script (ambiente isolado)..."
docker run -it --rm \
  -v "$SCRIPT_DIR/setup_dev_machine.sh:/scripts/setup_dev_machine.sh:ro" \
  ubuntu:22.04 \
  bash -c "apt-get update -y && apt-get install -y bash ca-certificates curl gnupg && bash /scripts/setup_dev_machine.sh"
