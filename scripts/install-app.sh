#!/bin/sh
set -eu

# Usage: scripts/install-app.sh [--bundle PATH] [--wait-idle SECS]
#   --bundle     install an already built Zendows.app instead of building one
#   --wait-idle  hold the restart until the keyboard and mouse have been idle for SECS seconds,
#                because restarting restores and re-tiles every window
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
source_bundle=
wait_idle=
while [ $# -gt 0 ]; do
  case "$1" in
    --bundle) source_bundle=$2; shift 2 ;;
    --wait-idle) wait_idle=$2; shift 2 ;;
    *) echo "usage: $0 [--bundle PATH] [--wait-idle SECS]" >&2; exit 2 ;;
  esac
done
# build-app.sh prints the built bundle path on its last line.
# Fork default: unsigned local builds unless the maintainer set a Developer ID.
if [ -z "$source_bundle" ]; then
  if [ -z "${ZENDOWS_RELEASE_UNSIGNED:-}" ] && [ -z "${ZENDOWS_CODESIGN_IDENTITY:-}" ]; then
    echo "No ZENDOWS_CODESIGN_IDENTITY set; building unsigned (ZENDOWS_RELEASE_UNSIGNED=1)." >&2
    echo "Configure a Developer ID before distributing builds." >&2
    export ZENDOWS_RELEASE_UNSIGNED=1
  fi
  source_bundle=$("$root/scripts/build-app.sh" | tail -n 1)
fi
[ -d "$source_bundle/Contents" ] || { echo "no Zendows.app at $source_bundle" >&2; exit 1; }
if [ -n "$wait_idle" ]; then
  idle_seconds() { ioreg -c IOHIDSystem | awk '/HIDIdleTime/ { print int($NF / 1000000000); exit }'; }
  while [ "$(idle_seconds)" -lt "$wait_idle" ]; do sleep 5; done
fi
install_root="/Applications"
installed_bundle="$install_root/Zendows.app"
cli_root="$HOME/.local/bin"
was_automatic=false

mkdir -p "$install_root"
if pgrep -x zendows-agent >/dev/null 2>&1; then
  status=$("$source_bundle/Contents/MacOS/zendows" ctl status 2>/dev/null || ZENDOWS_APPLICATION_SUPPORT="$HOME/Library/Application Support/Pane" "$source_bundle/Contents/MacOS/zendows" ctl status 2>/dev/null || true)
  case "$status" in
    *'"mode":"automatic"'*) was_automatic=true ;;
  esac
  if ! "$source_bundle/Contents/MacOS/zendows" ctl restart >/dev/null 2>&1 &&
     ! ZENDOWS_APPLICATION_SUPPORT="$HOME/Library/Application Support/Pane" "$source_bundle/Contents/MacOS/zendows" ctl restart >/dev/null 2>&1; then
    pkill -TERM -x zendows-agent
  fi
fi
for _ in $(seq 1 75); do
  pgrep -x zendows-agent >/dev/null 2>&1 || break
  sleep 0.2
done
if pgrep -x zendows-agent >/dev/null 2>&1; then
  echo "Zendows did not finish restoring windows; installation aborted" >&2
  exit 1
fi
rm -rf "$installed_bundle" "$install_root/Pane.app"
ditto "$source_bundle" "$installed_bundle"
codesign --verify --deep --strict "$installed_bundle"
mkdir -p "$cli_root"
rm -f "$cli_root/pane"
ln -sf "$installed_bundle/Contents/MacOS/zendows" "$cli_root/zendows"
for _ in $(seq 1 10); do
  open "$installed_bundle" 2>/dev/null && break
  sleep 0.2
done
if $was_automatic; then
  for _ in $(seq 1 75); do
    if "$installed_bundle/Contents/MacOS/zendows" ctl resume >/dev/null 2>&1; then
      break
    fi
    sleep 0.2
  done
fi

printf '%s\n' "$installed_bundle"
