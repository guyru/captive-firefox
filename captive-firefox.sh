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
#   -h, --help            Show this help message and exit
#
# Example:
#   ./captive-firefox.sh --iface wlan0 --url "http://example.com"
#

set -e

# --- Default configuration ---
URL="http://detectportal.firefox.com/canonical.html"
IFACE=""
FIREFOX_BIN="firefox"
FIREJAIL_BIN="firejail"

# full path to iw command, as /usr/sbin/ is not always in PATH
IW_BIN="/usr/sbin/iw"
if ! [ -x "$IW_BIN" ]; then
  IW_BIN="iw" # fallback to PATH if not found in /usr/sbin
fi

# --- Usage/help ---
usage() {
  grep '^#' "$0" | sed -e 's/^# \{0,1\}//'
}

# --- Parse arguments ---
while [[ $# -gt 0 ]]; do
  case "$1" in
    -u|--url)
      URL="$2"
      shift 2
      ;;
    -i|--iface)
      IFACE="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      usage
      exit 1
      ;;
  esac
done

# --- Wi-Fi Interface autodetect if not set ---
if [[ -z "$IFACE" ]]; then
  IFACE=$($IW_BIN dev 2>/dev/null | awk '$1=="Interface"{print $2}' | head -n1)
  if [[ -z "$IFACE" ]]; then
    echo "Error: Could not auto-detect Wi-Fi interface. Use --iface to specify."
    exit 1
  fi
fi

# --- Get DNS server from NetworkManager for the Wi-Fi interface ---
DNS=$(
  nmcli device show "$IFACE" 2>/dev/null | awk '/IP.\.DNS/ {print $2; exit}'
)
if [[ -z "$DNS" ]]; then
  echo "Error: Could not get DNS server for interface '$IFACE'. Are you connected via Wi-Fi?"
  exit 1
fi

# --- Run Firefox in Firejail with temporary profile and custom DNS ---
exec "$FIREJAIL_BIN" --dns="$DNS" --private "$FIREFOX_BIN" --no-remote "$URL"
