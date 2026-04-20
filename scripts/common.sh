#!/bin/bash

set -euo pipefail

BOX_ROOT_DIR="${BOX_ROOT_DIR:-/etc/box}"
BOX_CONFIG_FILE="${BOX_CONFIG_FILE:-$BOX_ROOT_DIR/box.env}"
TARGET_USER="${TARGET_USER:-telas}"
TARGET_HOME="${TARGET_HOME:-/home/$TARGET_USER}"
PLAYER_REPO_DIR="${PLAYER_REPO_DIR:-$TARGET_HOME/box-player}"
PLAYER_REPO_SLUG="${PLAYER_REPO_SLUG:-InnovatioLab/box-script-v2}"
ZABBIX_REPO_DIR="${ZABBIX_REPO_DIR:-$TARGET_HOME/instalador-client-zabbix}"
ZABBIX_REPO_SLUG="${ZABBIX_REPO_SLUG:-InnovatioLab/instalador-client-zabbix}"

log() {
  printf '[box-bootstrap] %s\n' "$*"
}

fail() {
  printf '[box-bootstrap] ERRO: %s\n' "$*" >&2
  exit 1
}

require_root() {
  if [ "${EUID:-$(id -u)}" -ne 0 ]; then
    fail "execute este script como root"
  fi
}

detect_os_release() {
  if [ ! -r /etc/os-release ]; then
    fail "/etc/os-release não encontrado"
  fi

  # shellcheck disable=SC1091
  . /etc/os-release
  OS_ID="${ID:-}"
  OS_VERSION_ID="${VERSION_ID:-}"
  OS_VERSION_CODENAME="${VERSION_CODENAME:-}"
}

require_supported_os() {
  detect_os_release

  if [ "$OS_ID" != "ubuntu" ] || [ "$OS_VERSION_ID" != "24.04" ]; then
    fail "suportado apenas em Ubuntu 24.04; detectado: ${OS_ID:-desconhecido} ${OS_VERSION_ID:-desconhecido}"
  fi
}

ensure_box_root() {
  install -d -m 0750 "$BOX_ROOT_DIR"
}

load_box_config() {
  ensure_box_root
  if [ ! -f "$BOX_CONFIG_FILE" ]; then
    fail "arquivo de configuração não encontrado em $BOX_CONFIG_FILE. Copie box.env.example para esse caminho e preencha os valores."
  fi

  # shellcheck disable=SC1090
  . "$BOX_CONFIG_FILE"
}

require_config_value() {
  local name="$1"
  local value="${!name:-}"
  if [ -z "$value" ]; then
    fail "defina a variável $name em $BOX_CONFIG_FILE"
  fi
}

ensure_target_user() {
  if ! id "$TARGET_USER" >/dev/null 2>&1; then
    fail "usuário alvo '$TARGET_USER' não existe"
  fi
}

run_as_target_user() {
  su -l "$TARGET_USER" -c "$*"
}

install_apt_prerequisites() {
  apt-get update -y
  apt-get install -y ca-certificates curl git gnupg jq lsb-release wget x11-xserver-utils
}

ensure_docker_repo() {
  install -m 0755 -d /etc/apt/keyrings
  if [ ! -f /etc/apt/keyrings/docker.gpg ]; then
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg
  fi

  cat > /etc/apt/sources.list.d/docker.list <<EOF
deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu ${OS_VERSION_CODENAME} stable
EOF
}

clone_or_update_repo() {
  local repo_slug="$1"
  local destination="$2"
  local branch="${3:-main}"

  require_config_value GITHUB_TOKEN

  if [ -d "$destination/.git" ]; then
    log "Atualizando repositório $repo_slug em $destination"
    git -C "$destination" -c http.extraheader="Authorization: Bearer $GITHUB_TOKEN" fetch --depth=1 origin "$branch"
    git -C "$destination" checkout -B "$branch" "origin/$branch"
  else
    log "Clonando repositório $repo_slug em $destination"
    rm -rf "$destination"
    git -c http.extraheader="Authorization: Bearer $GITHUB_TOKEN" clone --depth=1 --branch "$branch" "https://github.com/$repo_slug.git" "$destination"
  fi

  chown -R "$TARGET_USER:$TARGET_USER" "$destination"
}

ensure_shell_scripts_executable() {
  local target_dir="$1"

  if [ ! -d "$target_dir" ]; then
    return 0
  fi

  while IFS= read -r script_path; do
    chmod +x "$script_path"
  done < <(rg --files -g '*.sh' "$target_dir")
}

write_env_file_if_missing() {
  local env_path="$1"
  local resolved_zabbix_host=""

  resolved_zabbix_host="$(resolve_zabbix_host || true)"

  cat > "$env_path" <<EOF
API_KEY=${BOX_API_KEY:-}
PORT=${BOX_PORT:-8081}
API_BASE_URL=${BOX_API_BASE_URL:-https://api.telas-ads.com/api/}
ZABBIX_SERVER=${ZABBIX_SERVER:-100.111.249.88}
ZABBIX_HOST=${resolved_zabbix_host}
TAILSCALE_AUTH_KEY=${TAILSCALE_AUTH_KEY:-}
DISPLAY=${DISPLAY_VALUE:-:0}
EOF

  chown "$TARGET_USER:$TARGET_USER" "$env_path"
  chmod 0640 "$env_path"
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

detect_tailscale_ipv4() {
  if ! command_exists tailscale; then
    return 1
  fi

  tailscale ip -4 2>/dev/null | tr -d '[:space:]'
}

resolve_zabbix_host() {
  if [ -n "${ZABBIX_HOST:-}" ]; then
    printf '%s' "$ZABBIX_HOST"
    return 0
  fi

  local tailscale_ip=""
  tailscale_ip="$(detect_tailscale_ipv4 || true)"
  if [ -n "$tailscale_ip" ]; then
    printf '%s' "$tailscale_ip"
    return 0
  fi

  return 1
}
