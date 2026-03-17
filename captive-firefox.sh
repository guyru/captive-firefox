#!/bin/bash
#
# captive-firefox.sh
#
# Author: guyru
#
# Launches Firefox in a Firejail sandbox with DNS set to the DHCP-provided DNS server
# from your active Wi-Fi interface, using a temporary Firefox profile.
#
# Usage:
#   ./captive-firefox.sh [OPTIONS]
#
# Options:
#   -u, --url URL         Set the URL to open in Firefox (default: Firefox captive portal check)
#   -i, --iface IFACE     Specify the Wi-Fi interface (default: auto-detect)
#   --no-disable-jit      Do not disable JIT and WebAssembly (disabled by default for security)
#   -h, --help            Show this help message and exit
#
# Example:
#   ./captive-firefox.sh --iface wlan0 --url "http://example.com"
#

set -euo pipefail

# --- Default configuration ---
URL="http://detectportal.firefox.com/canonical.html"
IFACE=""
FIREFOX_BIN="firefox"
FIREJAIL_BIN="firejail"
DISABLE_JIT=true

# full path to iw command, as /usr/sbin/ is not always in PATH
IW_BIN="/usr/sbin/iw"
if ! [ -x "$IW_BIN" ]; then
  IW_BIN="iw" # fallback to PATH if not found in /usr/sbin
fi

# --- Usage/help ---
usage() {
  sed -n '/^#/!q; /^#!/d; s/^# \{0,1\}//; p' "$0"
}

# --- Dependency checks ---
check_deps() {
  local missing=()
  for cmd in "$FIREJAIL_BIN" "$FIREFOX_BIN" nmcli "$IW_BIN"; do
    if ! command -v "$cmd" &>/dev/null && ! [ -x "$cmd" ]; then
      missing+=("$cmd")
    fi
  done
  if [[ ${#missing[@]} -gt 0 ]]; then
    echo "Error: missing required dependencies: ${missing[*]}" >&2
    echo "Please install them and try again." >&2
    exit 1
  fi
}

# --- Parse arguments ---
while [[ $# -gt 0 ]]; do
  case "$1" in
    -u|--url)
      if [[ -z "${2:-}" ]]; then
        echo "Error: --url requires a value." >&2
        exit 1
      fi
      URL="$2"
      shift 2
      ;;
    -i|--iface)
      if [[ -z "${2:-}" ]]; then
        echo "Error: --iface requires a value." >&2
        exit 1
      fi
      IFACE="$2"
      shift 2
      ;;
    --no-disable-jit)
      DISABLE_JIT=false
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
done

# --- Check dependencies ---
check_deps

# --- Wi-Fi Interface autodetect if not set ---
if [[ -z "$IFACE" ]]; then
  IFACE=$($IW_BIN dev 2>/dev/null | awk '$1=="Interface"{print $2}' | head -n1)
  if [[ -z "$IFACE" ]]; then
    echo "Error: Could not auto-detect Wi-Fi interface. Use --iface to specify." >&2
    exit 1
  fi
fi

# --- Get DNS server from NetworkManager for the Wi-Fi interface ---
DNS=$(
  nmcli device show "$IFACE" 2>/dev/null | awk '/IP.\.DNS/ {print $2; exit}'
)
if [[ -z "$DNS" ]]; then
  echo "Error: Could not get DNS server for interface '$IFACE'. Are you connected via Wi-Fi?" >&2
  exit 1
fi

WORK_DIR=$(mktemp -d)
#cleanup temporary profile on exit
trap 'rm -rf "$WORK_DIR"' EXIT

mkdir -p "$WORK_DIR"/profile

# Create a minimal user.js to disable JIT and WebAssembly for better security in captive portal environments
if [[ "$DISABLE_JIT" == true ]]; then
cat <<EOF > "$WORK_DIR"/profile/user.js
user_pref("javascript.options.baselinejit", false);
user_pref("javascript.options.ion", false);
user_pref("javascript.options.wasm", false);
user_pref("javascript.options.asmjs", false);

// Disable the privacy notice page on first run
user_pref("datareporting.policy.dataSubmissionPolicyBypassNotification", true);

EOF
fi

# --- Run Firefox in Firejail with temporary profile and custom DNS ---
"$FIREJAIL_BIN" --dns="$DNS" --private="$WORK_DIR" --private-cwd "$FIREFOX_BIN" --no-remote "$URL" --profile="profile"
