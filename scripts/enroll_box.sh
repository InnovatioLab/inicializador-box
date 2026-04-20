#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./common.sh
. "$SCRIPT_DIR/common.sh"

main() {
  require_root
  require_supported_os
  load_box_config
  ensure_target_user

  require_config_value GITHUB_TOKEN
  require_config_value BOX_API_KEY

  install -d -m 0755 "$TARGET_HOME"
  install -d -m 0755 "$(dirname "$PLAYER_REPO_DIR")"

  clone_or_update_repo "$PLAYER_REPO_SLUG" "$PLAYER_REPO_DIR" "${PLAYER_REPO_BRANCH:-main}"

  local env_path="$PLAYER_REPO_DIR/.env"
  write_env_file_if_missing "$env_path"

  if [ -n "${BOX_ID:-}" ]; then
    if grep -q '^BOX_ID=' "$env_path"; then
      sed -i "s/^BOX_ID=.*/BOX_ID=$BOX_ID/" "$env_path"
    else
      printf 'BOX_ID=%s\n' "$BOX_ID" >> "$env_path"
    fi
  fi

  chmod 0640 "$env_path"
  chown "$TARGET_USER:$TARGET_USER" "$env_path"

  log "Matrícula da box concluída"
}

main "$@"
