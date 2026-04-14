#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./common.sh
. "$SCRIPT_DIR/common.sh"

install_tailscale() {
  if [ "${INSTALL_TAILSCALE:-true}" != "true" ]; then
    log "Instalação do Tailscale desabilitada por configuração"
    return 0
  fi

  if ! command_exists tailscale; then
    log "Instalando Tailscale"
    curl -fsSL https://tailscale.com/install.sh | sh
  fi

  systemctl enable tailscaled
  systemctl restart tailscaled

  if [ -n "${TAILSCALE_AUTH_KEY:-}" ] && ! tailscale status >/dev/null 2>&1; then
    log "Autenticando Tailscale"
    tailscale up --authkey="${TAILSCALE_AUTH_KEY}" --ssh
  fi
}

install_zabbix() {
  if [ "${INSTALL_ZABBIX:-true}" != "true" ]; then
    log "Instalação do Zabbix desabilitada por configuração"
    return 0
  fi

  clone_or_update_repo "$ZABBIX_REPO_SLUG" "$ZABBIX_REPO_DIR" "${ZABBIX_REPO_BRANCH:-main}"
  ensure_shell_scripts_executable "$ZABBIX_REPO_DIR"

  local zabbix_script="$ZABBIX_REPO_DIR/zabbix_manager_ubuntu.sh"
  if [ ! -f "$zabbix_script" ]; then
    fail "script do Zabbix não encontrado em $zabbix_script"
  fi

  chmod +x "$zabbix_script"
  log "Executando instalador do Zabbix"
  bash "$zabbix_script"
}

main() {
  require_root
  require_supported_os
  load_box_config
  ensure_target_user

  install_tailscale
  install_zabbix

  log "Observabilidade concluída"
}

main "$@"
