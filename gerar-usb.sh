#!/bin/bash
# gerar-usb.sh — Gera USB de instalação automática de uma telas box.
#
# Uso:
#   sudo ./gerar-usb.sh --box-id box-002 --device /dev/sdb
#   sudo ./gerar-usb.sh --box-id box-002 --device /dev/sdb --tailscale-key tskey-auth-...
#
# O USB instala Ubuntu 24.04 + Docker + AnyDesk + Tailscale + player
# sem nenhuma interação humana. Apenas BOX_ID muda entre boxes.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

UBUNTU_ISO_NAME="ubuntu-24.04.2-live-server-amd64.iso"
UBUNTU_ISO_URL="https://releases.ubuntu.com/24.04/${UBUNTU_ISO_NAME}"
ISO_CACHE_DIR="${HOME}/.cache/telas-box-isos"
WORK_DIR=""

BOX_ID=""
DEVICE=""
TAILSCALE_KEY=""

# ---------------------------------------------------------------------------
log()  { printf '\033[1;36m[gerar-usb]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[gerar-usb] AVISO:\033[0m %s\n' "$*"; }
fail() { printf '\033[1;31m[gerar-usb] ERRO:\033[0m %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<EOF
Uso: sudo $0 --box-id BOX_ID --device /dev/sdX [--tailscale-key TSKEY]

  --box-id         ID único da box (ex: box-001)      [obrigatório]
  --device         Dispositivo USB (ex: /dev/sdb)     [obrigatório]
  --tailscale-key  Auth key do Tailscale               [opcional]

O dispositivo USB será completamente sobrescrito.
EOF
  exit 1
}

parse_args() {
  [ $# -eq 0 ] && usage
  while [ $# -gt 0 ]; do
    case "$1" in
      --box-id)        BOX_ID="$2";        shift 2 ;;
      --device)        DEVICE="$2";        shift 2 ;;
      --tailscale-key) TAILSCALE_KEY="$2"; shift 2 ;;
      -h|--help)       usage ;;
      *) fail "Argumento desconhecido: $1" ;;
    esac
  done
  [ -z "$BOX_ID" ]  && fail "--box-id é obrigatório"
  [ -z "$DEVICE" ]  && fail "--device é obrigatório"
}

check_root() {
  [ "${EUID:-$(id -u)}" -ne 0 ] && fail "Execute como root: sudo $0 $*"
}

check_deps() {
  local missing=()
  for cmd in xorriso wget python3 lsblk; do
    command -v "$cmd" >/dev/null 2>&1 || missing+=("$cmd")
  done
  if [ ${#missing[@]} -gt 0 ]; then
    fail "Dependências ausentes: ${missing[*]}.
  Ubuntu/Debian : sudo apt-get install ${missing[*]}
  NixOS         : nix-env -iA $(printf 'nixpkgs.%s ' "${missing[@]}")
  NixOS (sudo)  : sudo env PATH=\"\$PATH\" ./gerar-usb.sh ..."
  fi
}

confirm_device() {
  echo ""
  warn "O dispositivo '$DEVICE' será COMPLETAMENTE APAGADO:"
  lsblk "$DEVICE" 2>/dev/null || true
  echo ""
  read -r -p "Confirma? Digite 'sim' para continuar: " answer
  [ "$answer" = "sim" ] || fail "Cancelado."
}

# ---------------------------------------------------------------------------
download_iso() {
  mkdir -p "$ISO_CACHE_DIR"
  local iso_path="$ISO_CACHE_DIR/$UBUNTU_ISO_NAME"
  if [ -f "$iso_path" ]; then
    log "ISO em cache: $iso_path"
  else
    log "Baixando $UBUNTU_ISO_NAME..."
    wget -c --show-progress -O "$iso_path" "$UBUNTU_ISO_URL"
  fi
  printf '%s' "$iso_path"
}

extract_iso() {
  local iso_path="$1"
  log "Extraindo ISO..."
  xorriso -osirrox on -indev "$iso_path" -extract / "$WORK_DIR/iso_src" >/dev/null 2>&1
  chmod -R u+w "$WORK_DIR/iso_src"
}

patch_grub() {
  local grub_cfg="$WORK_DIR/iso_src/boot/grub/grub.cfg"
  [ -f "$grub_cfg" ] || fail "grub.cfg não encontrado no ISO."
  log "Patchando GRUB para boot automático..."
  python3 - "$grub_cfg" <<'EOF'
import sys, re
path = sys.argv[1]
with open(path) as f:
    text = f.read()
# Boot imediato, sem esperar o menu
text = re.sub(r'^set timeout=\d+', 'set timeout=0', text, flags=re.MULTILINE)
# Injeta autoinstall na primeira linha "linux" com vmlinuz
def inject(m):
    line = m.group(0)
    if 'autoinstall' not in line:
        line = line.rstrip() + ' autoinstall ds=nocloud;s=file:///cdrom/server/'
    return line
text = re.sub(r'^\s+linux\s+\S*vmlinuz\S*.*$', inject, text, count=1, flags=re.MULTILINE)
with open(path, 'w') as f:
    f.write(text)
print("grub.cfg patchado.")
EOF
}

generate_user_data() {
  local server_dir="$WORK_DIR/iso_src/server"
  mkdir -p "$server_dir"

  # Lê valores defaults do setup_dev_machine.sh
  local github_token box_api_key
  github_token=$(grep 'DEFAULT_GITHUB_TOKEN=' "$SCRIPT_DIR/setup_dev_machine.sh" \
    | head -1 | cut -d'"' -f2)
  box_api_key=$(grep 'DEFAULT_BOX_API_KEY=' "$SCRIPT_DIR/setup_dev_machine.sh" \
    | head -1 | cut -d'"' -f2)

  local ts_key_line="TAILSCALE_AUTH_KEY="
  [ -n "$TAILSCALE_KEY" ] && ts_key_line="TAILSCALE_AUTH_KEY=${TAILSCALE_KEY}"

  log "Gerando user-data para BOX_ID=${BOX_ID}..."

  # user-data = autoinstall.yaml com valores desta box específica
  cat > "$server_dir/user-data" <<YAML
#cloud-config
autoinstall:
  version: 1
  identity:
    realname: "Telas Box"
    hostname: telas-${BOX_ID}
    username: telas
    password: "\$y\$j9T\$OhqrINdty2I6i4C6p6Mxc.\$voXUZ4zGpvnMFggMVHWkoP3hwu1w94oQPyt7DisUxp0"
  locale: en_US.UTF-8
  keyboard:
    layout: us
  timezone: "America/New_York"
  packages:
    - ca-certificates
    - curl
    - git
    - gnupg
    - jq
    - wget
  codecs:
    install: true
  drivers:
    install: true
  ssh:
    install-server: true
    authorized-keys:
      - ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBPoeRr1TEfBSiZTjZoWIRvFh/k6e+zJmov2uO5R61M4 victoremmanuelmn@gmail.com
      - ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCSGTm0GwW61itb9ZXhG1Gc7sSud5T/v9uoclz9Jr1HRlBnFowPROO/4wDTC0ALrBQELEvDo1lEnh2SBJS5GuzSShG2OoMXdfQiCUIyOZT+tOdjLiDcgi7XkjT126jrknS1Diw+ySKcKuJPPeSF6FBVOR7FDPrInTqHm+oHoYdyo71DV7vI/YqUTpKTc4NaCZJ8IPSliXvjMM9xHBWhm3svpRoVuD6FySsEhWaXt5KnJjhBfKktrWevnBZU/GbjOiveAztQf0shSA9j16oTM7TAt3Jg5RbPl9lv1DlmsJmD4VXaeOJEvsc6hNlqcp1wsMSS1WOIg9uac+wkin6dP5aV9VVB6c/LPY4ZKtMqlZ9BmuqciZ+P70pSvPllXCBAgwDWm989b6Xh9TCe3ObY1KosgfJFoDHRG/CkyAgs2trqyfe6xvvg3gxeN7gzaIujs42Fc0zFDcFG3lqe86UCScPjYnxQKB8AJYVe9a3ZuTBpC/Gh9mlXWbkbKl6vNHJAtjIwdA1mhF9OnxJxPce2WX6xpZsJgZ2H/b63k0RXR7PtaRIsr8wiWnEXmHZcuatkkKrmTTTm8sUhD++s4VvR6bjECtxI/QMGV3ie6iBFtaQVshH8BeRWx4CRcSjJUzNGWeJPH3OkstRRQ6B8KWrbMOs02K18GBJFE/X+X39uuWGhVQ== kevindiegodasilvasousa@gmail.com
  updates: all
  shutdown: reboot
  late-commands:
    - |
      chroot /target /bin/bash -c '
        mkdir -p /etc/box
        cat > /etc/box/box.env <<ENVEOF
TARGET_USER=telas
ENABLE_AUTOLOGIN=true
GITHUB_TOKEN=${github_token}
PLAYER_REPO_SLUG=InnovatioLab/box-script-v2
PLAYER_REPO_BRANCH=main
BOX_API_KEY=${box_api_key}
BOX_API_BASE_URL=https://api.telas-ads.com/api/
BOX_PORT=8081
BOX_ID=${BOX_ID}
INSTALL_TAILSCALE=true
${ts_key_line}
DISPLAY_VALUE=:0
ENVEOF
        chmod 0640 /etc/box/box.env
      '
    - |
      chroot /target /bin/bash -c '
        mkdir -p /root/inicializador-box
        curl -fsSL "https://github.com/InnovatioLab/inicializador-box/archive/refs/heads/main.tar.gz" \
          | tar -xz --strip-components=1 -C /root/inicializador-box
      '
    - |
      chroot /target /bin/bash -c 'cat > /etc/systemd/system/box-firstboot.service <<SVCEOF
[Unit]
Description=Bootstrap da telas box no primeiro boot
ConditionPathExists=/root/inicializador-box/setup_dev_machine.sh
ConditionPathExists=!/etc/box/bootstrap.complete
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/bin/bash /root/inicializador-box/setup_dev_machine.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
SVCEOF
      systemctl enable box-firstboot.service'
YAML

  # meta-data vazio é obrigatório para o NoCloud datasource
  touch "$server_dir/meta-data"
  log "user-data gerado."
}

repack_iso() {
  local output_iso="$WORK_DIR/telas-${BOX_ID}.iso"
  log "Reempacotando ISO..."

  xorriso -as mkisofs \
    -r \
    -V "TELAS-${BOX_ID}" \
    -o "$output_iso" \
    -J --joliet-long \
    -b boot/grub/i386-pc/eltorito.img \
    -c boot.catalog \
    -no-emul-boot \
    -boot-load-size 4 \
    -boot-info-table \
    --grub2-boot-info \
    --grub2-mbr "$WORK_DIR/iso_src/boot/grub/i386-pc/boot_hybrid.img" \
    -append_partition 2 28732ac11ff8d211ba4b00a0c93ec93b \
      "$WORK_DIR/iso_src/boot/grub/efi.img" \
    -appended_part_as_gpt \
    -eltorito-alt-boot \
    -e '--interval:appended_partition_2:::' \
    -no-emul-boot \
    -partition_offset 16 \
    "$WORK_DIR/iso_src" \
    2>/dev/null

  printf '%s' "$output_iso"
}

write_to_usb() {
  local iso="$1"
  log "Gravando em $DEVICE (pode levar alguns minutos)..."
  dd if="$iso" of="$DEVICE" bs=4M conv=fsync status=progress
  sync
}

cleanup() {
  [ -n "$WORK_DIR" ] && [ -d "$WORK_DIR" ] && rm -rf "$WORK_DIR"
}

# ---------------------------------------------------------------------------
main() {
  parse_args "$@"
  check_root
  check_deps
  confirm_device

  WORK_DIR=$(mktemp -d /tmp/telas-usb.XXXXXX)
  trap cleanup EXIT

  local iso_path output_iso
  iso_path=$(download_iso)
  extract_iso "$iso_path"
  patch_grub
  generate_user_data
  output_iso=$(repack_iso)
  write_to_usb "$output_iso"

  echo ""
  log "USB pronto para BOX_ID=${BOX_ID}"
  log ""
  log "  1. Plugue no NUC com boot por USB habilitado"
  log "  2. Ligue — instala tudo sozinho (~15 min), reinicia"
  log "  3. No primeiro login o player já sobe automaticamente"
}

main "$@"
