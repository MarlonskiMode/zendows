#!/usr/bin/env bash
# Publishes Zendows to the Anomaly release service (anomalyco/release
# docs/publishing.md) through its shared client, vendored as
# release-client.sh, so nothing fetched at run time executes here. The client
# trades the job's GitHub OIDC token for a one-hour publish session, uploads,
# publishes and re-downloads the file to check it. Runs only in the Release
# workflow's publish jobs, which have `id-token: write` and the release
# environment that anomalyco/release registry/zendows.json requires.
#
#   release-service.sh publish <dir> <notes-url>     # upload macos-arm64 zip, then publish release
#   release-service.sh distribution <kind> <version> # a package manager now serves <version>
#
# <dir> holds Zendows-$ZENDOWS_VERSION-macos-arm64.zip, published as target
# macos-arm64 under the name Zendows.zip. RELEASE is https://anoma.ly/release,
# ZENDOWS_RELEASE_CHANNEL the channel. `publish` writes <dir>/manifest.json.
# A rerun of the channel's current version succeeds when it is exactly these
# files.
. "$(dirname "$0")/lib.sh"

: "${RELEASE:?Set RELEASE to the release service origin}"
: "${ZENDOWS_VERSION:?Set ZENDOWS_VERSION}"
: "${ZENDOWS_RELEASE_CHANNEL:?Set ZENDOWS_RELEASE_CHANNEL}"
[ "$RELEASE" = https://anoma.ly/release ] || die "RELEASE must be https://anoma.ly/release."

temporary=$(mktemp -d)
trap 'rm -rf "$temporary"' EXIT
client() { RELEASE=$RELEASE bash "$(dirname "$0")/release-client.sh" "$@"; }

# The package managers that mirror Zendows, each as the service lists it.
distributions='[
  {"kind": "brew", "cask": "MarlonskiMode/homebrew-tap/zendows", "command": "brew upgrade --cask MarlonskiMode/homebrew-tap/zendows"}
]'

publish() {
  local dir=$1 notes_url=$2 zip
  zip="$dir/Zendows-$ZENDOWS_VERSION-macos-arm64.zip"
  [ -f "$zip" ] || die "Missing $zip."

  jq -n --arg channel "$ZENDOWS_RELEASE_CHANNEL" --arg version "$ZENDOWS_VERSION" --arg notes_url "$notes_url" \
    --argjson distributions "$distributions" \
    '{channel: $channel, version: $version, distributions: ([{kind: "direct"}] + $distributions)}
      + (if $notes_url == "" then {} else {notes_url: $notes_url} end)' > "$temporary/release.json"
  client publish --app zendows --artifact desktop \
    --release "$temporary/release.json" --out "$dir/manifest.json" --verify-downloads \
    --target "macos-arm64=$zip=Zendows.zip"
}

distribution() {
  # The whole entry, so recording a version never drops its command.
  local entry
  entry=$(printf '%s' "$distributions" | jq -ec --arg kind "$1" --arg version "$2" \
    'map(select(.kind == $kind))[0] // error("unknown distribution \($kind)") | . + {version: $version}')
  client distribution --app zendows --artifact desktop --channel "$ZENDOWS_RELEASE_CHANNEL" --entry "$entry"
}

case "${1:-}" in
  publish)
    [ $# -eq 3 ] || die "Usage: release-service.sh publish <dir> <notes-url>"
    publish "$2" "$3"
    ;;
  distribution)
    [ $# -eq 3 ] || die "Usage: release-service.sh distribution <kind> <version>"
    distribution "$2" "$3"
    ;;
  *)
    die "Usage: release-service.sh publish <dir> <notes-url> | distribution <kind> <version>"
    ;;
esac
