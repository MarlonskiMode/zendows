# Security And Privacy

## Accessibility Scope

Zendows needs macOS Accessibility permission to enumerate eligible application windows, read their
role, state, title, position, and size, determine focus, and focus, move, or resize them. It also reads
the on-screen Core Graphics window list, display topology, keyboard input source, pointer position,
and mouse-button state needed for tiling and gestures. Two listen-only event taps watch three-finger
trackpad swipes and Option key presses. The key tap reads only the virtual key code and modifier flags
of presses with Option held, never characters, to notice a Zendows shortcut macOS did not deliver;
other presses are ignored and nothing is stored.

The permission is broad because macOS grants Accessibility at application scope. Zendows limits its
own writes to eligible standard, non-minimized, non-fullscreen windows whose position is settable.
Resizable windows may be moved and resized; movable non-resizable windows may be parked off-screen
and restored without changing their size. It does not require disabling System Integrity Protection.

## Data Handling

Zendows has no telemetry or analytics. **This fork disables the in-app updater** so it does not
contact Anomaly’s release service (`anoma.ly/release/...`) or any other host under the Zendows
brand. Sparkle keys were removed from `app/Info.plist`. The updater code remains in-tree with
placeholder origins (`example.invalid`) for a future private release host; `Updater::start` keeps
the worker offline. Other runtime data stays on the Mac unless the user shares CLI output or files.

The optional `Launch at Login` menu action registers or unregisters the signed main app through
macOS Service Management. Registration is stored and enforced by macOS; Zendows does not install a
separate helper, daemon, or launch-agent plist.

Zendows can read a window title for exact config-rule matching. Titles remain in memory and are
explicitly excluded from serialized observations, persisted state, the arrangement journal,
`zendows ctl debug`, `zendows doctor`, and `zendows hud` output.

The Workspace HUD shows each workspace's app icons. The runtime sends the agent each window's bundle
identifier and its layout rectangle, never a title, and the agent reads the icons from the installed
apps on the Mac. Nothing about the HUD is written to disk or logged.

Local files live under `~/Library/Application Support/Zendows/`:

- `config.toml`: user-authored configuration;
- `workspace-state.json`: active workspace selectors, previous-workspace history, logical slots,
  last-focused tile intent, Fullscreen Layout state, floating-window ownership, and layout trees;
- `parked-windows.json`: physical process/window identifiers and original frames needed for recovery;
- `window-memory.json`: per-application bundle identifiers with each remembered window's workspace,
  floating state, and last frame, used to restore placements after relaunches and reboots;
- `agent.log`: timestamped diagnostic events (switches, parking, restoration, ownership changes) with
  process/window identifiers and frames, never window titles. Focus-follow switches also record
  how long ago a key, click, or modifier change happened and whether Command was held, never which
  keys were pressed; mode `0600`, moved to `agent.log.1`
  (replacing any previous generation) past 5 MB at the next launch. Terminal launches keep
  diagnostics on stderr instead;
- `journal.jsonl` and `journal.jsonl.1`: the arrangement journal summarized by `zendows doctor`.
  It records process IDs, window-server IDs, bundle identifiers, frames, workspace ownership, parked
  state, and debounced model/screen disagreements, never window titles; mode `0600`, rotated past
  4 MiB with one previous generation kept. App-bundle and terminal launches both write it;
- `control.sock`: local Unix control socket, mode `0600`;
- `control.lock`: single-agent lock, mode `0600`.

State files contain application process/window identity, bundle identifiers, and geometry, but no
window titles. The code uses atomic replacement for the JSON state files and restricts the Application Support directory to
mode `0700`; do not sync or publish recovery state without reviewing it.

## Native Interfaces

Most integration uses macOS Accessibility, AppKit, Carbon hotkeys, Core Foundation, and Core Graphics.
Zendows dynamically resolves the private `_AXUIElementGetWindow` function to associate an
Accessibility element with a Core Graphics window ID. If that symbol disappears or changes, window
discovery can fail. This private API prevents Mac App Store distribution and is a compatibility and
review risk for any public release.

See [SECURITY.md](../SECURITY.md) for vulnerability reporting.
