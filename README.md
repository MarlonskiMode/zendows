# Zendows

Zendows is a personal rename fork of [Spaceman](https://github.com/anomalyco/spaceman) (MIT,
Anomaly / Kit Langton). It is an experimental macOS tiling window manager built around stable
logical windows. A native window, including a selected Ghostty native tab, can change physical
Accessibility identity without creating a new tile. Zendows keeps the logical slot and replaces its
physical binding when the evidence is unambiguous.

> This is **not** official Spaceman. Upstream lives at
> [anomalyco/spaceman](https://github.com/anomalyco/spaceman). This fork is
> [MarlonskiMode/zendows](https://github.com/MarlonskiMode/zendows).

> [!WARNING]
> Disable AeroSpace, yabai, Amethyst, and every other window manager before first opening Zendows
> or installing it from source. Two managers can repeatedly move the same windows. Keep the parked
> window state until Zendows has successfully paused or quit and restored every window.

Zendows currently:

- starts automatic tiling when Accessibility permission and its global hotkeys are available;
- provides ten default numbered workspaces plus opt-in named workspaces A-Z, with 1-5 on the main
  display and 6-10 on the secondary display by default;
- assigns workspaces to `main`, `secondary`, a display UUID, or an exact display name, falling back
  to the main display when a preferred display disconnects;
- persists active workspaces, nested split layouts, tile order and weights, and parked-window recovery
  metadata across Zendows restarts, and remembers each application's window placements by bundle
  identifier so reboots and startup recovery return windows to their workspaces;
- journals window arrangements and model/screen disagreements locally, summarized in Settings (`Activity`)
  and by `zendows doctor`;
- shows a non-activating Workspace HUD capsule on each display on workspace switches,
  cross-workspace moves, and layout toggles (`[settings] hud = true`);
- supports directional focus and movement across displays, drag-to-reorder/nest, mouse and keyboard
  resizing, balancing, and a workspace-wide Fullscreen Layout;
- keeps movable non-resizable and rule-floated windows with their logical workspace without tiling
  or resizing them;
- exposes a local CLI over a user-only Unix socket.

Zendows uses Accessibility APIs to observe, focus, move, and resize eligible windows. It requires no
SIP change. Read [Security and privacy](docs/security-and-privacy.md),
[Compatibility](docs/compatibility.md), and [Limitations](docs/limitations.md) before trying it.

## Signing, notarization, and updates (fork)

Upstream Spaceman ships Developer ID–signed, notarized Apple silicon builds and checks Anomaly’s
release service for updates. **This fork does not reuse Anomaly’s Developer ID, team ID,
notarization, Sparkle feed, or `anoma.ly/release` endpoints.**

- In-app updates are **disabled** (`src/updater.rs`).
- Sparkle keys (`SUFeedURL`, etc.) were removed from `app/Info.plist`.
- `app/update-requirement.txt` uses placeholder team `YOURTEAMID` until you configure signing.
- Local builds should use `ZENDOWS_RELEASE_UNSIGNED=1` until you have a Developer ID Application
  identity. Gatekeeper will treat unsigned builds differently from the official Spaceman preview.
- First real Apple silicon build/sign/notarize is a follow-up for the maintainer.

## Install From Source (Apple silicon)

Requirements: macOS on Apple silicon, Xcode command-line tools, Rust 1.100.0.

1. Disable every other window manager. For AeroSpace: `aerospace enable off`.
2. Build an unsigned app bundle and install it:

```sh
ZENDOWS_RELEASE_UNSIGNED=1 ./scripts/build-app.sh
# then copy target/Zendows.app to /Applications, or:
ZENDOWS_RELEASE_UNSIGNED=1 ./scripts/install-app.sh
```

If you already have a Developer ID Application identity:

```sh
ZENDOWS_CODESIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" ./scripts/install-app.sh
```

3. Open `/Applications/Zendows.app`, grant Accessibility under the new bundle ID
   `com.marlonskimode.zendows` (this does **not** share the official Spaceman grant), then press
   `Start Tiling`.
4. Optionally link the CLI:

```sh
mkdir -p "$HOME/.local/bin"
ln -sf "/Applications/Zendows.app/Contents/MacOS/zendows" "$HOME/.local/bin/zendows"
```

Ensure `~/.local/bin` is on `PATH`. State and config live under
`~/Library/Application Support/Zendows/` (separate from Spaceman’s
`~/Library/Application Support/Spaceman/`).

## First Open

1. Disable every other window manager. For AeroSpace: `aerospace enable off`.
2. Open Zendows: `open "/Applications/Zendows.app"`.
3. On a fresh install, Zendows opens its three-step setup tour when Accessibility access is missing.
   Choose `Allow` and grant Zendows access in **System Settings > Privacy & Security**, optionally
   enable `Launch at Login`, then press `Start Tiling`.
4. Confirm operation with `zendows ctl status`.

Automatic tiling starts when the setup tour finishes. Without Accessibility permission, the menu
reports the permission error and tiling remains paused. Menu actions include `Pause Tiling` /
`Resume Tiling`, `Workspace HUD`, `Launch at Login`, `Settings...` (`⌘,`), and `Quit Zendows`
(`⌘Q`). “Check for Updates…” stays unavailable in this fork until a private release host is wired.

## Everyday Use

Core controls:

| Keys | Action |
| --- | --- |
| `Option+1` ... `Option+9`, `Option+0` | Switch to workspace 1 ... 10 |
| `Option+Shift+1` ... `Option+Shift+0` | Move the focused window to workspace 1 ... 10 |
| `Option+A` ... `Option+Z` | Switch to a configured named workspace |
| `Option+Shift+A` ... `Option+Shift+Z` | Move the focused window to a configured named workspace |
| `Option+Tab` | Return to the previous workspace on the focused display |
| `Option+Shift+Tab` | Move the focused workspace to the next display |
| Option-backtick | Focus the next tiled window in the workspace |
| `Option+H/J/K/L` | Focus left/down/up/right |
| `Option+Shift+H/J/K/L` | Move the focused tile left/down/up/right |
| `Option+/` | Toggle the active layout's root split axis |
| `Option+-`, `Option+=` | Shrink/grow the focused tile by 50 pixels |
| `Option+←`, `Option+→` | Snap a lone tiled window to left/right half (again restores full) |
| `Option+Shift+F` | Toggle Fullscreen Layout without native fullscreen |
| `Option+Shift+Space` | Float the focused window above the tiles, or tile it again |
| Three-finger swipe left/right | Next/previous occupied workspace on the display under the pointer |

See [Controls](docs/controls.md) for drag, resize, balance, CLI, and socket behavior.

```sh
zendows ctl status
zendows ctl switch 2
zendows ctl move 7
zendows ctl layout
zendows ctl float
zendows ctl balance
zendows ctl pause
zendows ctl resume
```

## Configure

Zendows reads `~/Library/Application Support/Zendows/config.toml` at startup and reloads rule,
display, and HUD edits automatically when the file changes. See
[config.example.toml](config.example.toml) and [Configuration](docs/configuration.md).

```sh
zendows config-check "$HOME/Library/Application Support/Zendows/config.toml"
zendows displays
```

Env overrides: `ZENDOWS_CONFIG`, `ZENDOWS_APPLICATION_SUPPORT`, `ZENDOWS_MANAGED_DISPLAY`.

## Recover Or Remove

Use `zendows ctl pause` or `zendows ctl quit` and wait for `zendows ctl status` or process exit to
confirm that restoration completed **before** removing the app or state. Do not delete
`parked-windows.json` as an early troubleshooting step.

Follow [Recovery](docs/recovery.md) for stuck or crashed processes and safe uninstall instructions.

## Documentation

- [Configuration](docs/configuration.md)
- [Controls](docs/controls.md)
- [Recovery and uninstall](docs/recovery.md)
- [Security and privacy](docs/security-and-privacy.md)
- [Compatibility](docs/compatibility.md)
- [Known limitations](docs/limitations.md)
- [Development](docs/development.md)
- [Releasing](docs/releasing.md) (fork: signing/release host not configured)
- [Contributing](CONTRIBUTING.md)
- [Security policy](SECURITY.md)
- [NOTICE](NOTICE) — upstream attribution

## Status

Personal MIT fork of Spaceman for rebranding and local use. No signed/notarized Zendows preview is
published yet; build from source on Apple silicon. Auto-update against Anomaly is intentionally
off.

## License

MIT. Copyright for upstream Spaceman remains with Kit Langton / Anomaly as in [LICENSE](LICENSE).
See [NOTICE](NOTICE) for fork attribution. This project is not affiliated with Anomaly.
