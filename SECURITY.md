# Security Policy

## Project Status

Zendows is an experimental personal fork of [Spaceman](https://github.com/anomalyco/spaceman)
without a guaranteed security maintenance window. It is not the official Spaceman product.

## Reporting A Vulnerability

Do not file a public issue for a suspected vulnerability or include private window/state data in a
report. Contact the repository owner privately; if GitHub private vulnerability reporting is enabled,
use the repository's **Security > Report a vulnerability** flow.

Include the affected revision, macOS version and architecture, impact, minimal reproduction, and any
suggested mitigation. Redact window titles, bundle IDs where sensitive, local paths beyond those
needed to explain the issue, and the contents of `parked-windows.json` or `workspace-state.json`.

The maintainer will acknowledge the report, assess scope, and coordinate disclosure when practical.
No response-time guarantee applies while the project remains experimental.

For vulnerabilities that also affect upstream Spaceman, consider reporting to
[anomalyco/spaceman](https://github.com/anomalyco/spaceman) as well.

## Scope Notes

Zendows has broad Accessibility permission and uses private `_AXUIElementGetWindow`. The local
control socket and lock are mode `0600`. There is no telemetry.

**Updates:** this fork disables the in-app updater so it does not contact Anomaly’s release service
(`anoma.ly/release/...`) under the Zendows brand. Sparkle feed keys were removed from
`app/Info.plist`. Builds are unsigned unless you configure your own Developer ID. See
[Security and privacy](docs/security-and-privacy.md) and the README signing section.
