#!/usr/bin/env bash
#
# Route A helper: run a repo-local LiveKit server for the demo.
#
# LiveKit publishes no macOS binary in its GitHub releases, so `install` builds
# the official server from source with the local Go toolchain. Every Go cache is
# redirected into .local/ so nothing outside this repository is touched and
# `rm -rf .local` cleans up completely.
#
# Usage:
#   bash scripts/livekit-dev.sh install   # build .local/bin/livekit-server
#   bash scripts/livekit-dev.sh start     # start in dev mode on the LAN
#   bash scripts/livekit-dev.sh status    # pid + port + api key
#   bash scripts/livekit-dev.sh env       # print LIVEKIT_* exports for demo-server
#   bash scripts/livekit-dev.sh logs      # tail the server log
#   bash scripts/livekit-dev.sh stop      # stop the server
#
# Dev mode intentionally uses the fixed devkey/secret pair. It is a local
# development server: never expose it to the internet and never reuse these
# credentials on LiveKit Cloud (route B uses a real project key/secret).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOCAL_DIR="${LIVEKIT_LOCAL_DIR:-$REPO_ROOT/.local}"
BIN_DIR="$LOCAL_DIR/bin"
BIN="$BIN_DIR/livekit-server"
PID_FILE="$LOCAL_DIR/livekit.pid"
LOG_FILE="$LOCAL_DIR/livekit.log"
VERSION="${LIVEKIT_VERSION:-v1.13.7}"
PORT="${LIVEKIT_PORT:-7880}"
DEV_API_KEY="${LIVEKIT_API_KEY:-devkey}"
DEV_API_SECRET="${LIVEKIT_API_SECRET:-secret}"

log() { printf '%s\n' "$*" >&2; }

lan_ip() {
  local ip=""
  ip="$(ipconfig getifaddr en0 2>/dev/null || true)"
  [[ -n "$ip" ]] || ip="$(ipconfig getifaddr en1 2>/dev/null || true)"
  if [[ -z "$ip" ]]; then
    local iface
    iface="$(route -n get default 2>/dev/null | awk '/interface:/{print $2}')"
    [[ -n "$iface" ]] && ip="$(ipconfig getifaddr "$iface" 2>/dev/null || true)"
  fi
  [[ -n "$ip" ]] || ip="127.0.0.1"
  printf '%s' "$ip"
}

is_running() {
  [[ -f "$PID_FILE" ]] || return 1
  local pid
  pid="$(cat "$PID_FILE" 2>/dev/null || true)"
  [[ -n "$pid" ]] || return 1
  kill -0 "$pid" 2>/dev/null
}

cmd_install() {
  if [[ -x "$BIN" ]]; then
    log "livekit-server already present: $("$BIN" --version 2>/dev/null || echo unknown)"
    return 0
  fi
  if ! command -v go >/dev/null 2>&1; then
    cat >&2 <<'EOF'
Go toolchain not found, and LiveKit ships no macOS binary in its releases.

Options:
  brew install go        # then rerun: bash scripts/livekit-dev.sh install
  brew install livekit   # installs to /opt/homebrew instead of .local/
EOF
    exit 1
  fi
  mkdir -p "$BIN_DIR" "$LOCAL_DIR/gopath" "$LOCAL_DIR/gocache" "$LOCAL_DIR/src"
  log "building livekit-server $VERSION into $BIN_DIR"
  log "(first run clones the source and downloads Go modules; several minutes)"
  # `go install pkg@version` cannot be used: the LiveKit go.mod has replace
  # directives, which the toolchain rejects for versioned installs. A
  # tag-pinned shallow clone plus a local build is the supported equivalent.
  local src="$LOCAL_DIR/src/livekit"
  if [[ ! -d "$src/.git" ]]; then
    git clone --depth 1 --branch "$VERSION" \
      https://github.com/livekit/livekit.git "$src"
  else
    git -C "$src" fetch --depth 1 origin "refs/tags/$VERSION:refs/tags/$VERSION" 2>/dev/null || true
    git -C "$src" checkout --detach "$VERSION"
  fi
  (
    cd "$src"
    GOPATH="$LOCAL_DIR/gopath" \
    GOCACHE="$LOCAL_DIR/gocache" \
    GOMODCACHE="$LOCAL_DIR/gopath/pkg/mod" \
      go build -trimpath -o "$BIN" ./cmd/server
  )
  chmod +x "$BIN"
  log "installed: $("$BIN" --version 2>/dev/null || echo "$BIN")"
}

cmd_start() {
  if [[ ! -x "$BIN" ]]; then
    log "livekit-server not installed yet — run: bash scripts/livekit-dev.sh install"
    exit 1
  fi
  if is_running; then
    log "already running (pid $(cat "$PID_FILE")): $(cmd_url)"
    return 0
  fi
  local node_ip
  node_ip="${LIVEKIT_NODE_IP:-$(lan_ip)}"
  log "starting livekit-server on 0.0.0.0:$PORT (node-ip $node_ip)"
  mkdir -p "$LOCAL_DIR"
  nohup "$BIN" --dev --bind 0.0.0.0 --node-ip "$node_ip" >>"$LOG_FILE" 2>&1 &
  echo $! >"$PID_FILE"
  local i
  for i in $(seq 1 40); do
    if curl -fsS -m 1 "http://127.0.0.1:$PORT/" >/dev/null 2>&1; then
      log "ready: $(cmd_url)"
      return 0
    fi
    sleep 0.25
  done
  log "server did not become ready in 10s; last log lines:"
  tail -n 20 "$LOG_FILE" >&2 || true
  exit 1
}

cmd_url() { printf 'ws://%s:%s' "${LIVEKIT_NODE_IP:-$(lan_ip)}" "$PORT"; }

cmd_env() {
  cat <<EOF
# Route A (local dev server). Source these before starting demo-server:
export LIVEKIT_URL=$(cmd_url)
export LIVEKIT_API_KEY=$DEV_API_KEY
export LIVEKIT_API_SECRET=$DEV_API_SECRET
EOF
}

cmd_status() {
  if is_running; then
    log "running (pid $(cat "$PID_FILE")) url=$(cmd_url)"
    curl -fsS -m 2 "http://127.0.0.1:$PORT/" >/dev/null 2>&1 \
      && log "http check: ok" || log "http check: failed"
  else
    log "not running"
    return 1
  fi
}

cmd_stop() {
  if ! is_running; then
    log "not running"
    rm -f "$PID_FILE"
    return 0
  fi
  local pid
  pid="$(cat "$PID_FILE")"
  kill "$pid" 2>/dev/null || true
  local i
  for i in $(seq 1 20); do
    kill -0 "$pid" 2>/dev/null || break
    sleep 0.25
  done
  kill -0 "$pid" 2>/dev/null && kill -9 "$pid" 2>/dev/null || true
  rm -f "$PID_FILE"
  log "stopped"
}

cmd_logs() { tail -n "${1:-40}" "$LOG_FILE"; }

case "${1:-}" in
  install) shift; cmd_install "$@" ;;
  start)   shift; cmd_start "$@" ;;
  stop)    shift; cmd_stop "$@" ;;
  status)  shift; cmd_status "$@" ;;
  env)     shift; cmd_env "$@" ;;
  url)     shift; cmd_url "$@" ;;
  logs)    shift; cmd_logs "$@" ;;
  *)
    sed -n '3,22p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
    exit 1
    ;;
esac
