#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./common.sh
. "$SCRIPT_DIR/common.sh"

install_display_helper() {
  install -m 0755 "$SCRIPT_DIR/../setup_graphic_session.sh" /usr/local/bin/box-display-access.sh
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

  systemctl start box-display-access.service || true
  systemctl restart box-player.service

  log "Instalação do player concluída"
}

main "$@"
