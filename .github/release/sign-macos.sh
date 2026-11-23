#!/usr/bin/env bash
# sign-macos.sh <unsigned Zendows.app zip> <out dir>: signs Zendows.app
# inside-out with the Developer ID identity (hardened runtime, secure
# timestamp): both executables, then the bundle. Notarizes and staples it, and
# writes Zendows-<version>-macos-arm64.zip (root Zendows.app) with its
# .sha256. The app is data here: it is never launched.
#
# Environment: ZENDOWS_VERSION (the release's version),
# ZENDOWS_BUNDLE_VERSION (Cargo.toml's, which the bundle carries),
# ZENDOWS_SIGNING_IDENTITY, ZENDOWS_KEYCHAIN, ZENDOWS_NOTARY_KEY,
# ZENDOWS_NOTARY_KEY_ID, ZENDOWS_NOTARY_ISSUER (macos-credentials.sh).
. "$(dirname "$0")/lib.sh"

input=$1
out=$2
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir -p "$out"
name="Zendows-$ZENDOWS_VERSION-macos-arm64.zip"

/usr/bin/ditto -x -k "$input" "$work/unpacked"
app="$work/unpacked/Zendows.app"
if [ ! -d "$app" ] || [ "$(find "$work/unpacked" -mindepth 1 -maxdepth 1 | wc -l | tr -d ' ')" != 1 ]; then
  die "The macOS build must hold exactly Zendows.app."
fi
plist="$app/Contents/Info.plist"
[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$plist")" = com.marlonskimode.zendows ] ||
  die "Zendows.app has the wrong bundle identifier."
[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$plist")" = "$ZENDOWS_BUNDLE_VERSION" ] ||
  die "Zendows.app is not version $ZENDOWS_BUNDLE_VERSION."

# Every Mach-O in the bundle must be one this script signs; anything else would
# ship unsigned or unnoticed.
expected=$(printf '%s\n' Contents/MacOS/zendows Contents/MacOS/zendows-agent | LC_ALL=C sort)
found=$(cd "$app" && find . -type f -exec sh -c 'file -b "$1" | grep -q Mach-O && printf "%s\n" "${1#./}"' _ {} \; | LC_ALL=C sort)
[ "$found" = "$expected" ] || die "Unexpected code in Zendows.app: $(echo "$found" | tr '\n' ' ')"
for executable in zendows zendows-agent; do
  [ "$(lipo -archs "$app/Contents/MacOS/$executable")" = arm64 ] || die "$executable is not an arm64 binary."
done

sign() {
  codesign --force --timestamp --options runtime --keychain "$ZENDOWS_KEYCHAIN" \
    --sign "$ZENDOWS_SIGNING_IDENTITY" "$@"
}
sign "$app/Contents/MacOS/zendows-agent"
sign "$app/Contents/MacOS/zendows"
sign --identifier com.marlonskimode.zendows "$app"
codesign --verify --deep --strict --verbose=2 "$app"

# zip, as scripts/release-app.sh always has: symlinks kept, no __MACOSX
# entries, which validate-release.sh refuses.
(cd "$work/unpacked" && /usr/bin/zip -qry --symlinks "$work/notarize.zip" Zendows.app)
xcrun notarytool submit "$work/notarize.zip" --key "$ZENDOWS_NOTARY_KEY" --key-id "$ZENDOWS_NOTARY_KEY_ID" \
  --issuer "$ZENDOWS_NOTARY_ISSUER" --wait --timeout 45m --output-format json > "$work/notary.json" || true
cat "$work/notary.json"
status=$(jq -r '.status // empty' "$work/notary.json" 2>/dev/null || true)
if [ "$status" != Accepted ]; then
  id=$(jq -r '.id // empty' "$work/notary.json" 2>/dev/null || true)
  if [ -n "$id" ]; then
    xcrun notarytool log "$id" --key "$ZENDOWS_NOTARY_KEY" --key-id "$ZENDOWS_NOTARY_KEY_ID" \
      --issuer "$ZENDOWS_NOTARY_ISSUER" || true
  fi
  die "Notarization ended with status '${status:-unknown}'."
fi
xcrun stapler staple "$app"
xcrun stapler validate "$app"

out=$(cd "$out" && pwd)
rm -f "$out/$name"
(cd "$work/unpacked" && /usr/bin/zip -qry --symlinks "$out/$name" Zendows.app)
(cd "$out" && shasum -a 256 "$name" > "$name.sha256")
ls -l "$out"
