#!/bin/sh
# Builds target/Zendows.app.
# Zendows fork: prefer ZENDOWS_RELEASE_UNSIGNED=1 for local Apple silicon builds
# until the maintainer configures a Developer ID. Signed builds use
# ZENDOWS_CODESIGN_IDENTITY (or the first Developer ID in the keychain).
# Upstream stamped RELEASE_BUILD for Anomaly auto-updates; this fork keeps the
# in-app updater disabled regardless of that stamp.
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
bundle="$root/target/Zendows.app"
icon_output="$root/target/AppIcon.assets"
icon_info="$root/target/AppIcon-info.plist"
identity=${ZENDOWS_CODESIGN_IDENTITY:-}
unsigned=${ZENDOWS_RELEASE_UNSIGNED:-}
deployment_target=$(/usr/bin/plutil -extract LSMinimumSystemVersion raw "$root/app/Info.plist")
sdk_version=$(/usr/bin/xcrun --sdk macosx --show-sdk-version)
cargo_bin=${CARGO:-}

if [ -z "$cargo_bin" ]; then
  cargo_bin=$(command -v cargo 2>/dev/null || true)
fi
if [ -z "$cargo_bin" ] && [ -x "$HOME/.cargo/bin/cargo" ]; then
  cargo_bin="$HOME/.cargo/bin/cargo"
fi
if [ -z "$cargo_bin" ] || ! command -v "$cargo_bin" >/dev/null 2>&1; then
  echo "cargo was not found; install Rust 1.100.0 or set CARGO to its absolute path." >&2
  exit 1
fi

case "$unsigned" in
  ''|1) ;;
  *)
    echo "ZENDOWS_RELEASE_UNSIGNED must be 1 or unset, not '$unsigned'." >&2
    exit 1
    ;;
esac
if [ -z "$unsigned" ]; then
  if [ -z "$identity" ]; then
    identity=$(security find-identity -v -p codesigning \
      | sed -n 's/.*"\(Developer ID Application:[^"]*\)".*/\1/p' \
      | head -1)
  fi
  if [ -z "$identity" ]; then
    echo "No Developer ID Application identity found; set ZENDOWS_CODESIGN_IDENTITY." >&2
    exit 1
  fi
  case "$identity" in
    "Developer ID Application:"*) ;;
    *)
      echo "ZENDOWS_CODESIGN_IDENTITY must be a Developer ID Application identity, not '$identity'." >&2
      exit 1
      ;;
  esac
fi

release_channel=${ZENDOWS_RELEASE_CHANNEL:-}
release_version=${ZENDOWS_RELEASE_VERSION:-}
case "$release_channel" in
  ''|stable|dev) ;;
  *)
    echo "ZENDOWS_RELEASE_CHANNEL must be stable, dev or unset, not '$release_channel'." >&2
    exit 1
    ;;
esac
case "$release_version" in
  '') ;;
  .*|*[!A-Za-z0-9.+_-]*)
    echo "ZENDOWS_RELEASE_VERSION must be a version name, not '$release_version'." >&2
    exit 1
    ;;
esac
if { [ -n "$release_channel" ] && [ -z "$release_version" ]; } ||
  { [ -z "$release_channel" ] && [ -n "$release_version" ]; }; then
  echo "Set both ZENDOWS_RELEASE_CHANNEL and ZENDOWS_RELEASE_VERSION, or neither." >&2
  exit 1
fi

# Fork: never stamp ZENDOWS_RELEASE_BUILD. Upstream used it to enable Anomaly
# release-service polling; Zendows leaves the updater disabled in src/updater.rs.
unset ZENDOWS_RELEASE_BUILD
if [ -n "$release_channel" ]; then
  export ZENDOWS_RELEASE_CHANNEL="$release_channel" ZENDOWS_RELEASE_VERSION="$release_version"
else
  unset ZENDOWS_RELEASE_CHANNEL ZENDOWS_RELEASE_VERSION
fi
CARGO_TARGET_DIR="$root/target" \
  "$cargo_bin" build --manifest-path "$root/Cargo.toml" --release --locked --workspace --bins
# A global MACOSX_DEPLOYMENT_TARGET also applies to host-side proc-macro
# dylibs, which must remain loadable by the build host. Set the deployment
# command only on the final app executables before they are signed.
for executable in zendows-agent zendows; do
  path="$root/target/release/$executable"
  patched="$path.deployment-target"
  /usr/bin/vtool -set-build-version macos "$deployment_target" "$sdk_version" \
    -replace -output "$patched" "$path"
  /bin/chmod 755 "$patched"
  /bin/mv "$patched" "$path"
done
rm -rf "$bundle"
mkdir -p "$bundle/Contents/MacOS" "$bundle/Contents/Resources"
cp "$root/target/release/zendows-agent" "$bundle/Contents/MacOS/zendows-agent"
cp "$root/target/release/zendows" "$bundle/Contents/MacOS/zendows"
cp "$root/app/Info.plist" "$bundle/Contents/Info.plist"
rm -rf "$icon_output"
mkdir -p "$icon_output"
xcrun actool "$root/app/AppIcon.icon" \
  --compile "$icon_output" \
  --platform macosx \
  --minimum-deployment-target "$deployment_target" \
  --app-icon AppIcon \
  --standalone-icon-behavior all \
  --output-partial-info-plist "$icon_info" \
  --output-format human-readable-text \
  --warnings \
  --notices >&2
cp "$icon_output/AppIcon.icns" "$icon_output/Assets.car" "$bundle/Contents/Resources/"
plutil -lint "$bundle/Contents/Info.plist" >/dev/null
if [ -n "$unsigned" ]; then
  printf '%s\n' "$bundle"
  exit 0
fi
codesign --force --timestamp --options runtime --sign "$identity" \
  "$bundle/Contents/MacOS/zendows-agent"
codesign --force --timestamp --options runtime --sign "$identity" \
  "$bundle/Contents/MacOS/zendows"
codesign --force --timestamp --options runtime --sign "$identity" \
  --identifier com.marlonskimode.zendows \
  "$bundle"
codesign --verify --deep --strict "$bundle"

printf '%s\n' "$bundle"
