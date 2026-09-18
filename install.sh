#!/usr/bin/env bash
set -euo pipefail

# pg-node installer (Linux only)
# Downloads the latest GitHub release for the detected arch and installs to /usr/local/bin/<name>

REPO_OWNER="GamerKhaan"
REPO_NAME="node-serviced"
APP_NAME="pg-node"
INSTALL_PATH="/usr/local/bin/${APP_NAME}"
API_URL="https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/releases/latest"

ARCH=""
OS="linux"
TMPDIR=""

log() {
  printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >&2
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --name)
        if [[ -z "${2:-}" ]]; then
          log "--name requires a value"; exit 1
        fi
        APP_NAME="$2"
        INSTALL_PATH="/usr/local/bin/${APP_NAME}"
        shift 2
        ;;
      --name=*)
        APP_NAME="${1#*=}"
        if [[ -z "$APP_NAME" ]]; then
          log "--name requires a value"; exit 1
        fi
        INSTALL_PATH="/usr/local/bin/${APP_NAME}"
        shift
        ;;
      *)
        log "Unknown option: $1"
        exit 1
        ;;
    esac
  done
}

cleanup() {
  if [[ -n "${TMPDIR:-}" && -d "$TMPDIR" ]]; then
    rm -rf "$TMPDIR"
  fi
}
trap cleanup EXIT

detect_arch() {
  case "$(uname -m)" in
    x86_64|amd64) ARCH="amd64" ;;
    aarch64|arm64) ARCH="arm64" ;;
    armv7l|armv7) ARCH="armv7" ;;
    armv6l|armv6) ARCH="armv6" ;;
    *) log "Unsupported architecture: $(uname -m)"; exit 1 ;;
  esac
}

require_linux() {
  if [[ "$(uname -s)" != "Linux" ]]; then
    log "This installer supports Linux only."
    exit 1
  fi
}

require_tools() {
  for bin in curl tar; do
    if ! command -v "$bin" >/dev/null 2>&1; then
      log "Missing required tool: $bin"
      exit 1
    fi
  done
}

fetch_latest_url() {
  local asset_name="${APP_NAME}_*_Linux_${ARCH}.tar.gz"
  local url
  url=$(curl -sSf "$API_URL" | grep -oE "\"browser_download_url\": \"[^\"]*${asset_name}\"" | head -n1 | cut -d\" -f4)
  if [[ -z "$url" ]]; then
    log "Could not find a release asset for arch=${ARCH} and name=${APP_NAME}"
    exit 1
  fi
  echo "$url"
}

download_and_install() {
  TMPDIR=$(mktemp -d)
  local url="$1"
  local archive="$TMPDIR/${APP_NAME}.tar.gz"

  log "Downloading: $url"
  curl -fL "$url" -o "$archive"

  log "Extracting archive"
  tar -xzf "$archive" -C "$TMPDIR"

  local bin_path="$TMPDIR/${APP_NAME}"
  if [[ ! -f "$bin_path" ]]; then
    # Fallback to legacy binary name if archive name differs
    if [[ -f "$TMPDIR/node-serviced" ]]; then
      bin_path="$TMPDIR/node-serviced"
    else
      log "Binary ${APP_NAME} not found in archive"
      exit 1
    fi
  fi

  log "Installing to $INSTALL_PATH"
  install -m 0755 "$bin_path" "$INSTALL_PATH"
}

main() {
  parse_args "$@"
  require_linux
  require_tools
  detect_arch

  if [[ "$APP_NAME" != "pg-node" ]]; then
    log "Using custom name: $APP_NAME (asset must exist with this prefix)"
  fi

  log "Detected linux/${ARCH}"
  local url
  url=$(fetch_latest_url)

  download_and_install "$url"
  log "Install complete: $INSTALL_PATH"
}

main "$@"

