#!/bin/bash

set -euo pipefail

CURRENT_VERSION="2.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERSION_FILE="/etc/box/version"
BOX_CONFIG_FILE="/etc/box/box.env"
TARGET_USER="telas"
DEFAULT_GITHUB_TOKEN="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"
DEFAULT_BOX_API_KEY="Qw8!pZr2@tLx7sVb6kJm9^eHf4&uYc1"
DEFAULT_BOX_API_BASE_URL="https://api.telas-ads.com/api/"
DEFAULT_BOX_PORT="8081"
DEFAULT_BOX_ID="box-001"
DEFAULT_DISPLAY_VALUE=":0"

write_default_box_config() {
  cat > "$BOX_CONFIG_FILE" <<EOF
TARGET_USER=$TARGET_USER
ENABLE_AUTOLOGIN=true

GITHUB_TOKEN=$DEFAULT_GITHUB_TOKEN

PLAYER_REPO_SLUG=InnovatioLab/box-script-v2
PLAYER_REPO_BRANCH=main

BOX_API_KEY=$DEFAULT_BOX_API_KEY
BOX_API_BASE_URL=$DEFAULT_BOX_API_BASE_URL
BOX_PORT=$DEFAULT_BOX_PORT
BOX_ID=$DEFAULT_BOX_ID

INSTALL_TAILSCALE=true
TAILSCALE_AUTH_KEY=

DISPLAY_VALUE=$DEFAULT_DISPLAY_VALUE
EOF

  chmod 0640 "$BOX_CONFIG_FILE"
}

write_pending_instructions() {
  local note_path="/etc/box/README-BOOTSTRAP.txt"
  cat > "$note_path" <<EOF
O bootstrap automatico da box foi preparado e o arquivo principal de configuracao foi criado.

1. Edite o arquivo:
   $BOX_CONFIG_FILE

2. Revise principalmente:
   - GITHUB_TOKEN
   - BOX_API_KEY
   - BOX_ID

3. Se usar Tailscale, preencha tambem:
   - TAILSCALE_AUTH_KEY

4. Finalize o provisionamento com:
   sudo /root/inicializador-box/setup_dev_machine.sh

6. Para validar o player depois:
   systemctl status box-player.service
   docker ps

Observacao: a configuracao da BIOS para religar apos queda de energia continua manual.
EOF

  chmod 0644 "$note_path"

  if id "$TARGET_USER" >/dev/null 2>&1; then
    install -d -m 0755 "/home/$TARGET_USER/Desktop"
    cp "$note_path" "/home/$TARGET_USER/Desktop/README-BOOTSTRAP.txt"
    chown "$TARGET_USER:$TARGET_USER" "/home/$TARGET_USER/Desktop/README-BOOTSTRAP.txt"
  fi
}

run_step() {
  local label="$1"
  local script_path="$2"

  chmod +x "$script_path"
  echo
  echo "==> $label"
  bash "$script_path"
}

main() {
  if [ "${EUID:-$(id -u)}" -ne 0 ]; then
    echo "Por favor, rode como root (ex: sudo ./setup_dev_machine.sh)"
    exit 1
  fi

  echo "Iniciando o bootstrap da box (versão $CURRENT_VERSION)"

  install -d -m 0750 /etc/box
  if [ ! -f "$BOX_CONFIG_FILE" ]; then
    write_default_box_config
    write_pending_instructions
    echo "Arquivo de configuração criado automaticamente em $BOX_CONFIG_FILE"
    echo "Continuando o bootstrap com os valores configurados."
  fi

  run_step "Bootstrap do host" "$SCRIPT_DIR/scripts/bootstrap_host.sh"
  run_step "Observabilidade" "$SCRIPT_DIR/scripts/install_observability.sh"
  run_step "Matrícula da box" "$SCRIPT_DIR/scripts/enroll_box.sh"
  run_step "Instalação do player" "$SCRIPT_DIR/scripts/install_player.sh"

  printf '%s\n' "$CURRENT_VERSION" > "$VERSION_FILE"
  chmod 0644 "$VERSION_FILE"
  touch /etc/box/bootstrap.complete
  systemctl disable box-firstboot.service >/dev/null 2>&1 || true

  echo
  echo "Bootstrap concluído com sucesso."
  echo "Se este for o primeiro provisionamento, reinicie a máquina para validar autologin, Docker e box-player.service."
}

main "$@"
