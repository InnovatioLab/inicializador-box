#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./common.sh
. "$SCRIPT_DIR/common.sh"

install_display_helper() {
  install -m 0755 "$SCRIPT_DIR/../setup_graphic_session.sh" /usr/local/bin/box-display-access.sh
}

install_gnome_autostart() {
  local start_script="$TARGET_HOME/start-box.sh"
  local autostart_dir="$TARGET_HOME/.config/autostart"
  local desktop_file="$autostart_dir/box-script.desktop"
  local display_val="${DISPLAY_VALUE:-:0}"

  cat > "$start_script" <<EOF
#!/bin/bash

# Aguarda o GNOME estabilizar antes de iniciar
sleep 15

export DISPLAY=${display_val}
export XAUTHORITY=$TARGET_HOME/.Xauthority

# Fecha o overlay de Activities do GNOME, se estiver aberto
xdotool key Escape

# Permite que containers Docker acessem o servidor X11
xhost +local:docker

cd $PLAYER_REPO_DIR
docker compose up -d
EOF

  chmod 0755 "$start_script"
  chown "$TARGET_USER:$TARGET_USER" "$start_script"

  install -d -m 0755 "$autostart_dir"
  chown "$TARGET_USER:$TARGET_USER" "$autostart_dir"

  cat > "$desktop_file" <<EOF
[Desktop Entry]
Type=Application
Name=Box Script
Exec=$start_script
X-GNOME-Autostart-enabled=true
EOF

  chown "$TARGET_USER:$TARGET_USER" "$desktop_file"
  chmod 0644 "$desktop_file"

  log "start-box.sh e autostart configurados para o usuário $TARGET_USER"
}

install_systemd_units() {
  cat > /etc/systemd/system/box-display-access.service <<EOF
[Unit]
Description=Prepare X11 access for the box player
After=graphical.target
Wants=graphical.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/box-display-access.sh ${TARGET_USER} ${DISPLAY_VALUE:-:0}

[Install]
WantedBy=graphical.target
EOF

  cat > /etc/systemd/system/box-player.service <<EOF
[Unit]
Description=Start box player containers
Requires=docker.service
After=docker.service network-online.target graphical.target box-display-access.service tailscaled.service
Wants=network-online.target graphical.target box-display-access.service tailscaled.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=${PLAYER_REPO_DIR}
Environment=DISPLAY=${DISPLAY_VALUE:-:0}
ExecStartPre=/usr/bin/test -f ${PLAYER_REPO_DIR}/docker-compose.yml
ExecStart=/usr/bin/docker compose up -d --build --remove-orphans
ExecStop=/usr/bin/docker compose down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  systemctl enable box-display-access.service
  systemctl enable box-player.service
}

main() {
  require_root
  require_supported_os
  load_box_config
  ensure_target_user

  if [ ! -f "$PLAYER_REPO_DIR/docker-compose.yml" ]; then
    fail "repositório do player não encontrado em $PLAYER_REPO_DIR. Execute enroll_box.sh antes."
  fi

  ensure_shell_scripts_executable "$PLAYER_REPO_DIR"
  install_display_helper
  install_systemd_units
  install_gnome_autostart

  systemctl start box-display-access.service || true
  systemctl restart box-player.service

  log "Instalação do player concluída"
}

main "$@"
