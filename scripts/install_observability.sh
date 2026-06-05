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

main() {
  require_root
  require_supported_os
  load_box_config
  ensure_target_user

  install_tailscale

  log "Observabilidade concluída"
}

main "$@"
