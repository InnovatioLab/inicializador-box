#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./common.sh
. "$SCRIPT_DIR/common.sh"

configure_autologin() {
  if [ "${ENABLE_AUTOLOGIN:-true}" != "true" ]; then
    log "Autologin desabilitado por configuração"
    return 0
  fi

  if [ -f /etc/gdm3/custom.conf ]; then
    if grep -q "^AutomaticLoginEnable" /etc/gdm3/custom.conf; then
      sed -i 's/^AutomaticLoginEnable=.*/AutomaticLoginEnable=true/' /etc/gdm3/custom.conf
    else
      printf '\nAutomaticLoginEnable=true\n' >> /etc/gdm3/custom.conf
    fi

    if grep -q "^AutomaticLogin=" /etc/gdm3/custom.conf; then
      sed -i "s/^AutomaticLogin=.*/AutomaticLogin=$TARGET_USER/" /etc/gdm3/custom.conf
    else
      printf 'AutomaticLogin=%s\n' "$TARGET_USER" >> /etc/gdm3/custom.conf
    fi

    log "Autologin configurado no gdm3 para $TARGET_USER"
    return 0
  fi

  log "gdm3 não encontrado; pulando configuração de autologin"
}

main() {
  require_root
  require_supported_os
  load_box_config
  ensure_target_user

  log "Instalando base do host"
  install_apt_prerequisites
  ensure_docker_repo

  apt-get update -y
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

  systemctl enable docker
  systemctl start docker

  usermod -aG docker "$TARGET_USER"

  install -d -m 0755 "$TARGET_HOME/Documentos"
  chown -R "$TARGET_USER:$TARGET_USER" "$TARGET_HOME"

  configure_autologin

  log "Bootstrap do host concluído"
}

main "$@"
