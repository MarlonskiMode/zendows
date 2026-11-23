#!/bin/sh
# Zendows fork: upstream Spaceman published signed zips to Anomaly's release
# service and Sparkle appcast. This fork does not reuse those endpoints or
# Anomaly's Developer ID / team. Configure your own release host, signing
# identity, and notarization before restoring a publish path.
set -eu

echo "scripts/release-app.sh is disabled in the Zendows fork." >&2
echo "It previously published to Anomaly (anoma.ly/release) and must not run under this brand." >&2
echo "See docs/releasing.md and README.md for what to set up first." >&2
exit 1
