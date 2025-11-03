#!/bin/bash
set -e
# setup_graphic_session.sh
# Wait for an X display socket and run xhost commands as the graphical user.
# Usage: setup_graphic_session.sh [username] [display]
#   username: user that owns the graphical session (default: telas)
USER_NAME="${1:-}"
DISPLAY_ADDR="${2:-}"
TIMEOUT=60
INTERVAL=1
elapsed=0

log() { echo "[setup_graphic_session] $*"; }

# Helper: detect X sockets and return first display (e.g. :0)
detect_display_from_socket() {
  shopt -s nullglob
  local sockets=(/tmp/.X11-unix/X*)
  if [ ${#sockets[@]} -eq 0 ]; then
    return 1
  fi
  # Prefer the lowest display number (X0, X1,...)
  local best=""
  for s in "${sockets[@]}"; do
    # filename like /tmp/.X11-unix/X0 -> display :0
    local base=${s##*/}
    local num=${base#X}
    if [ -z "$best" ] || [ "$num" -lt "${best#X}" ]; then
      best="$base"
    fi
  done
  printf ":%s" "${best#X}"
  return 0
}

# Helper: find X process (Xorg or Xwayland) PID
find_x_process_pid() {
  local pid
  pid=$(pgrep -x Xorg | head -n1) || true
  if [ -z "$pid" ]; then
    pid=$(pgrep -f Xwayland | head -n1) || true
  fi
  printf "%s" "$pid"
}

# Helper: try to read DISPLAY from /proc/<pid>/environ (if available)
display_from_proc_environ() {
  local pid=$1
  if [ -n "$pid" ] && [ -r "/proc/$pid/environ" ]; then
    tr '\0' '\n' < "/proc/$pid/environ" | awk -F= '/^DISPLAY=/{print $2; exit}' || true
  fi
}

# Helper: determine user owning display/socket
determine_user_for_display() {
  local disp_socket="$1"
  # Check socket owner if socket path provided
  if [ -n "$disp_socket" ] && [ -e "$disp_socket" ]; then
    local uid
    uid=$(stat -c '%u' "$disp_socket" 2>/dev/null || true)
    if [ -n "$uid" ]; then
      getent passwd "$uid" | cut -d: -f1 || true
      return
    fi
  fi
  # Fallback: owner of X process
  local pid
  pid=$(find_x_process_pid)
  if [ -n "$pid" ]; then
    ps -o user= -p "$pid" 2>/dev/null | awk '{print $1}' || true
    return
  fi
  # Final fallback: use provided USER_NAME or 'telas'
  if [ -n "$USER_NAME" ]; then
    printf "%s" "$USER_NAME"
  else
    printf "telas"
  fi
}

# 1) If DISPLAY explicitly provided as arg, use it
if [ -n "$DISPLAY_ADDR" ]; then
  log "Using provided DISPLAY=$DISPLAY_ADDR"
else
  # 2) Try socket detection
  if DISPLAY_ADDR=$(detect_display_from_socket); then
    log "Detected DISPLAY via socket: $DISPLAY_ADDR"
  else
    # 3) Try reading from X process environ
    pid=$(find_x_process_pid)
    if [ -n "$pid" ]; then
      env_disp=$(display_from_proc_environ "$pid") || true
      if [ -n "$env_disp" ]; then
        DISPLAY_ADDR="$env_disp"
        log "Detected DISPLAY via process environ: $DISPLAY_ADDR (pid $pid)"
      else
        # fallback
        DISPLAY_ADDR=":0"
        log "No DISPLAY in proc environ; defaulting to $DISPLAY_ADDR"
      fi
    else
      DISPLAY_ADDR=":0"
      log "No X process found and no socket; defaulting to $DISPLAY_ADDR"
    fi
  fi
fi

# Determine socket path from DISPLAY_ADDR
SOCKET_PATH="/tmp/.X11-unix/X${DISPLAY_ADDR#:}"

# Determine user to run xhost as
GRAPHICAL_USER=$(determine_user_for_display "$SOCKET_PATH")
log "Will run xhost as user: $GRAPHICAL_USER on display $DISPLAY_ADDR (socket $SOCKET_PATH)"

# Wait until socket exists (but don't fail if it never appears)
elapsed=0
while [ ! -e "$SOCKET_PATH" ] && [ $elapsed -lt $TIMEOUT ]; do
  sleep $INTERVAL
  elapsed=$((elapsed + INTERVAL))
done

if [ -e "$SOCKET_PATH" ]; then
  log "X socket found at $SOCKET_PATH; executing xhost commands"
  export DISPLAY="$DISPLAY_ADDR"
  if command -v xhost >/dev/null 2>&1; then
    # Run commands as the graphical user to avoid authorization issues
    su -l "$GRAPHICAL_USER" -c "DISPLAY=$DISPLAY xhost +local:docker || true; DISPLAY=$DISPLAY xhost +SI:electronuser:electronuser || true"
    log "xhost commands executed"
  else
    log "xhost not installed on system; skipping"
  fi
else
  log "X socket $SOCKET_PATH not found after ${TIMEOUT}s; nothing to do"
fi

exit 0
