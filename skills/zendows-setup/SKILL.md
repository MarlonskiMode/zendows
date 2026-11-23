---
name: zendows-setup
description: Install, configure, verify, troubleshoot, or uninstall the Zendows tiling window manager on macOS. Use when a user asks to set up Zendows, configure window rules or workspaces, transition from another window manager, recover off-screen windows, or remove Zendows.
---

# Zendows Setup

Zendows is an experimental native macOS tiling window manager for Apple silicon. Version 0.3.3 is
signed by Anomaly (`com.marlonskimode.zendows`), notarized, and distributed outside the Mac App Store. The
preview declares macOS 14.0 as its minimum; compatibility is not yet broadly qualified.

## Install

Disable any other window manager first — two managers fight over the same windows:

```sh
aerospace enable off   # AeroSpace
yabai --stop-service   # yabai
```

Download, verify, and open:

```sh
cd "$(mktemp -d)"
if [[ -e "/Applications/Zendows.app" ]]; then
  echo "Zendows is already installed; upgrade through Zendows Settings." >&2
  exit 1
fi
curl -fL "https://github.com/MarlonskiMode/zendows/download/macos-arm64" -o Zendows.zip
curl -fL "https://github.com/MarlonskiMode/zendows/download/macos-arm64.sha256" -o Zendows.zip.sha256
shasum -a 256 -c Zendows.zip.sha256
ditto -x -k Zendows.zip .
mv Zendows.app "/Applications/"
open "/Applications/Zendows.app"
```

Zendows opens a three-step setup tour: `Welcome`, `Give Zendows window access`, then
`You're all set`. Choose `Get started`, grant Accessibility access in
**System Settings > Privacy & Security**, optionally enable `Launch at Login`, and press
`Start Tiling`. Tiling stays paused while the tour is open, so granting permission never rearranges
windows behind it; automatic tiling starts when you press `Start Tiling`.

The permission list is named **Accessibility** through macOS 26, **Device Control and Data Access**
on macOS 27.0 through 27.2, and **System & App Protection Override** on macOS 27.3 and later. On 27.3
and later System Settings refuses dragged app tiles: click the Privacy & Security notification, or
use the list's `+` button to add Zendows. Never tell someone to drag Zendows into that list, and
never float a drag guide over System Settings there.

Source, issues and releases: <https://github.com/MarlonskiMode/zendows>.

## Verify

The CLI ships inside the bundle:

```sh
mkdir -p "$HOME/.local/bin"
ln -sf "/Applications/Zendows.app/Contents/MacOS/zendows" "$HOME/.local/bin/zendows"
"$HOME/.local/bin/zendows" ctl status   # healthy: "mode":"automatic" and "busy":false
```

## Controls

| Keys | Action |
| --- | --- |
| `Option+1` … `Option+0` | Switch to workspace 1 … 10 |
| `Option+Shift+1` … `Option+Shift+0` | Move focused window to workspace 1 … 10 |
| `Option+A` … `Option+Z` | Switch to a configured named workspace |
| `Option+Shift+A` … `Option+Shift+Z` | Move focused window to a configured named workspace |
| `Option+Tab` | Previous workspace on the focused display |
| `Option+backtick` | Focus the next tiled window in workspace order |
| `Option+H/J/K/L` | Focus left/down/up/right |
| `Option+Shift+H/J/K/L` | Move the focused tile |
| `Option+/` | Toggle the root split axis |
| `Option+-`, `Option+=` | Shrink/grow the focused tile |
| `Option+Shift+F` | Toggle workspace-wide Fullscreen Layout |

CLI: `zendows ctl switch 2`, `zendows ctl move 7`, `zendows ctl back-and-forth`,
`zendows ctl layout`, `zendows ctl balance`, `zendows ctl pause`, `zendows ctl resume`.

## Configure

Config lives at `~/Library/Application Support/Zendows/config.toml`, read at startup
(`ZENDOWS_CONFIG` overrides the path). Workspaces 1–5 prefer the main display, 6–10 the
secondary; assignments accept `main`, `secondary`, a display UUID, or a display name. Schema
version is `1`; rules are ordered and first-match. A rule accepts exact `bundle_id` and/or `title`
matching, with an `action` of `float`, `route`, or `ignore`; `route` also requires `workspace`.

```sh
zendows config-check "$HOME/Library/Application Support/Zendows/config.toml"
zendows displays
```

## Troubleshoot

- **Tiling never starts**: the setup tour is still open and waiting for `Start Tiling`, or
  Accessibility permission is missing. Open Settings, run the tour again, and check the menu bar item.
- **Hotkeys do nothing**: another app owns the `Option` shortcuts, or Accessibility permission is
  missing — the menu bar item reports which.
- **Windows off-screen after a crash**: reopen the same app, relaunch Zendows, and let it restore.
  Keep `parked-windows.json` — it records where those windows return. Do not remove recovery state
  until pause or quit has restored every window.
- **Windows keep moving on their own**: another window manager is running; quit it, then
  `zendows ctl resume`.
- **Updates**: Zendows checks Anomaly's release service and offers `Install & Restart` in Settings
  and the menu; it restores every window first.

## Uninstall

Turn off `Launch at Login` in Zendows Settings first, then restore and quit:

```sh
zendows ctl pause   # wait for "mode":"paused" and "busy":false
zendows ctl quit    # wait for zendows-agent to exit
```

Confirm windows returned, then:

```sh
rm -rf "/Applications/Zendows.app"
rm -f "$HOME/.local/bin/zendows"
rm -rf "$HOME/Library/Application Support/Zendows"
```
