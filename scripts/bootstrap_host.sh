#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./common.sh
. "$SCRIPT_DIR/common.sh"

install_anydesk() {
  if command_exists anydesk; then
    log "AnyDesk já instalado, pulando"
    return 0
  fi

  log "Instalando AnyDesk"
  curl -fsSL https://keys.anydesk.com/repos/DEB-GPG-KEY | gpg --dearmor -o /etc/apt/keyrings/anydesk.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/anydesk.gpg] http://deb.anydesk.com/ all main" \
    > /etc/apt/sources.list.d/anydesk-stable.list
  apt-get update -y
  apt-get install -y anydesk
}

disable_auto_updates() {
  log "Desativando atualizações automáticas..."

  # Desliga o daemon de upgrade não assistido
  systemctl disable unattended-upgrades.service 2>/dev/null || true
  systemctl stop    unattended-upgrades.service 2>/dev/null || true
  apt-get remove -y unattended-upgrades 2>/dev/null || true

  # Garante que apt não vai baixar ou instalar nada por conta própria
  cat > /etc/apt/apt.conf.d/20auto-upgrades <<EOF
APT::Periodic::Update-Package-Lists "0";
APT::Periodic::Download-Upgradeable-Packages "0";
APT::Periodic::AutocleanInterval "0";
APT::Periodic::Unattended-Upgrade "0";
EOF

  # Script que suprime o popup do update-manager no login do GNOME
  cat > /usr/local/bin/suppress-update-notifications.sh <<'EOF'
#!/bin/bash
gsettings set com.ubuntu.update-manager launch-time 0 2>/dev/null || true
pkill -f update-manager 2>/dev/null || true
EOF
  chmod +x /usr/local/bin/suppress-update-notifications.sh

  # Autostart para rodar o script acima em toda sessão do GNOME
  local autostart_dir="/home/$TARGET_USER/.config/autostart"
  install -d -m 0755 "$autostart_dir"
  cat > "$autostart_dir/suppress-updates.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Suppress Update Notifications
Exec=/usr/local/bin/suppress-update-notifications.sh
X-GNOME-Autostart-enabled=true
EOF
  chown -R "$TARGET_USER:$TARGET_USER" "$autostart_dir"

  log "Atualizações automáticas desativadas."
}

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

  install_anydesk
  disable_auto_updates
  configure_autologin

  log "Bootstrap do host concluído"
}

main "$@"
