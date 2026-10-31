# AGENTS.md

Quickshell (QML) Hyprland shell, deployed as a dotfiles package. This is a config repo, not a software project.

## There is no toolchain — do not look for one

- No `package.json`, build system, test runner, linter, formatter, typecheck, CI, pre-commit, or task runner exists. Nothing to "run".
- **Quickshell 0.3.2 is installed** (`qs --version`). The scaffold was written against 1.x, so most API names needed correcting — see the API section below. Verify against the installed version, not the README.
- The only real verification is `qs -p .config/quickshell` (or `qs` once stow-deployed). QML errors surface on load, so a clean launch is the smoke test.

## Deploying

```bash
cd ~/quickshell-theme && stow --dir=. --target="$HOME" .
```

- Creates `~/.config/quickshell` → `~/quickshell-theme/.config/quickshell`. Currently **not deployed** (`~/.config/quickshell` does not exist), so nothing you edit here is live.
- Undo with `stow --dir=. --target="$HOME" -D .`
- The whole repo root is stowed as one package. GNU Stow 2.4.1's default ignore list covers `README.md`, `.git`, and `.gitignore`, so only `.config` is linked. On stow < 2.4.0, `README.md` would land at `~/README.md` — check `stow --version` before running this elsewhere.
- The sibling repo `~/hypr-dotfiles` uses a *different* convention: one stow package per top-level directory plus an `install.sh` that dry-runs and backs conflicts up to `~/.dotfiles-backup-<timestamp>/`. This repo deliberately has no `install.sh`. Don't "fix" that asymmetry without asking.

## Layout and real entrypoints

- `.config/quickshell/shell.qml` is the only entrypoint (`ShellRoot`). One `PanelWindow` per monitor via `Variants { model: Quickshell.screens }`. The bar window is full-width but transparent; `Bar.qml` draws a centered pill inside it. The window reserves the pill's band via `exclusiveZone` (bound to `bar.barHeight + bar.topMargin`), so windows are pushed down while the pill still floats — drop `exclusionMode` entirely, since `ExclusionMode.Normal` is the default and what makes the reservation take effect.
- `Modules/Bar` (media / workspaces+clock / network+volume+memory+battery) and `Modules/Launcher` (rofi drun replacement) are live. `Modules/Notifications`, `Modules/OSD`, `Modules/Session` are still `visible: false` stubs whose intent lives in their `// TODO:` header comments.
- `Services/` holds the data singletons the bar reads (`Audio`, `Media`, `Battery`, `Network`, `Memory`) plus `Matugen`. See the Services section below — the lazy-initialisation rule there is the thing most likely to bite.

## Theme singleton — the non-obvious part

- `Theme/qmldir` is what registers the singleton (`singleton Theme 1.0 Theme.qml`) and must also declare `Colors 1.0 Colors.qml`. From `shell.qml` you write `import "Theme"`; from `Modules/<Name>/` you need `import "../../Theme"` (see the import section below).
- `Theme.qml` and `Services/Matugen.qml` both use `pragma Singleton` with root type `Singleton` from `import Quickshell`. Follow that shape.
- `Theme/Colors.qml` holds raw hex values (catppuccin-mocha defaults) and is the file matugen is meant to overwrite. Hand-edits there will not survive a palette regeneration.
- **The bar palette deliberately does not live in `Colors.qml`.** `Theme.qml` carries `fixedBar*` constants plus a `barUseMatugen` switch and four derived `bar*` properties. `Bar.qml` references only the derived ones, so flipping the bar between the fixed white pill and matugen colors is a one-line change in `Theme.qml`, not a bar rewrite. The fixed palette is white with near-black text — check contrast before lightening the text, since a white surface with the old light-gray text is unreadable.
- `Notifications`, `OSD`, and `Session` still hardcode `#1e1e2e` instead of referencing `Theme.barColor`. Replace those with `Theme` properties when fleshing the stubs out.

## Services — the lazy-initialisation trap

`Services/qmldir` declares each singleton the same way `Theme/qmldir` does. A qmldir singleton needs **both** the `Singleton` root type and a `pragma Singleton` line — either alone fails to load, and because a broken sibling takes the whole module down, one bad file surfaces as "Type Audio unavailable" for everything.

- **Quickshell initialises its services lazily.** `Mpris.players`, `UPower.devices`, `Hyprland.workspaces` and `Pipewire` all read as empty until something *observes* them. A `Connections { target: X; function onValuesChanged() {...} }` is what forces population — without one the model stays empty forever and the UI silently shows nothing. Every service wrapper in `Services/` carries one for this reason; it is load-bearing, not decorative.
- **Singletons instantiate lazily on first property access.** Referencing `Audio.volume` from inside a timer callback creates the instance at that moment, so its `Component.onCompleted` polling never gets a chance to run. Reference them from a binding that exists at load time (as `Bar.qml`'s text bindings do), not from a deferred callback.
- **`Pipewire` is unusable for sink volume here.** The default sink node stays `ready: false`, so `sink.audio.volume` reads 0 while `wpctl get-volume` reports the truth. `Services/Audio.qml` polls `wpctl` instead — read via `get-volume`, write via `set-volume`/`set-mute`, and re-read in `onExited` so the UI never shows a stale value.
- **`Networking` returns nothing here** — zero devices and `wifiEnabled: false` while NetworkManager is active and connected. `Services/Network.qml` polls `nmcli` instead: `device status` decides connectivity and medium, then `device wifi` adds signal strength.
- **No service covers memory.** `Services/Memory.qml` parses `/proc/meminfo`, using `MemAvailable` rather than `MemFree` as the basis for "used".
- `UPower.displayDevice` can report `ready: false` with a zero percentage until the device list is enumerated, so `Battery.qml` prefers the real `isLaptopBattery` device from `UPower.devices` and only falls back to `displayDevice`.
- Reading a `Process`'s output: attach a `StdioCollector` to `stdout` and handle `onStreamFinished`, where `this.text` holds the whole output. `waitForEnd` is not needed for short-lived commands.

## Working agreement

- **Never drive the user's input.** No synthetic keyboard/mouse via `/dev/uinput`, no screenshots to verify interactive behaviour. Inputs and clicks are the user's to test.
- **Verification is a separate phase.** When something needs checking, do it in a clearly separated troubleshooting step — not interleaved with implementation edits. Inline load checks (`qs -p .config/quickshell` starts clean) are fine.
- **`~/hypr-dotfiles` is read-only.** Read it for context (matugen templates, keybinds, waybar metrics) but never modify it.
- **Config belongs in this repo.** Add settings here rather than reaching into the sibling repo. When a change genuinely must land in `~/hypr-dotfiles` (the autostart line, a keybind), write the exact snippet for the user to apply instead of editing it yourself.

## Cross-repo coupling — the edits are often NOT in this repo

- **matugen is configured in the other repo**: `~/hypr-dotfiles/matugen/.config/matugen/config.toml`. Templates live in `~/hypr-dotfiles/matugen/.config/matugen/templates/` and use `{{colors.primary.default.hex}}`-style placeholders; each `[templates.*]` entry has `input_path`, `output_path`, and an optional signal-based `post_hook` (e.g. `pkill -SIGUSR2 waybar`).
- There is **no quickshell matugen template yet**. Making `Services/Matugen.qml`'s "matugen output feeds Theme/Colors.qml" comment true requires adding a `[templates.quickshell]` block to that `config.toml` with a template that emits QML. That config lives in `~/hypr-dotfiles`, so prepare the block + template and hand it to the user rather than editing it.
- **Hyprland autostart also lives in the other repo**: `~/hypr-dotfiles/hypr/.config/hypr/keybinds.lua`, line 11, `hl.exec_cmd("waybar")` inside `hl.on("hyprland.start", ...)`. Swapping waybar for `qs` is an edit *there* — hand the user the snippet, don't touch the file. Note the hypr config is written in Lua with an `hl.bind(mainMod .. " + X", hl.dsp.exec_cmd(cmd))` helper, not `hyprland.conf`.

## Quickshell API — verified against 0.3.2, not the 1.x scaffold

The Arch `*.qmltypes` files are **stale** (the Hyprland one is an empty stub). Trust runtime probes, not typeinfo. Verified facts:

- `Process.command` takes a **QStringList**, not a string. A plain string becomes a single argv element and fails to start. `Services/Matugen.qml`'s list form is correct.
- `DesktopEntry.command` is a **QStringList** (stringifies comma-joined). Pass it straight to `Process.command`; field codes like `%U` are already stripped.
- `DesktopEntries.applications` is an `UntypedObjectModel`. Read it as **`.values`** (a JS array), and wait for the **`applicationsChanged`** signal — it is empty at `Component.onCompleted` time. Same pattern for `Hyprland.workspaces.values`.
- **Services initialise lazily and stay empty until observed.** See the Services section — this is the single most common cause of a silently blank widget.
- `Hyprland.workspaces` carries the special workspace (`id === -98`) and is unordered. Filter to `id > 0` and sort before rendering.
- **`Hyprland.dispatch(request)` interpolates the request raw into a Lua call** (`return hl.dispatch(<request>)`), and this machine's Hyprland runs a Lua config. The legacy string form `"workspace N"` dies with a Lua syntax error (`')' expected near '1'`), and the quoted form `"'workspace N'"` dies with `expected a dispatcher`. The working request is a real dispatcher object: **`Hyprland.dispatch("hl.dsp.focus({workspace = " + id + "})")`** — confirmed switching *and* creating missing workspaces. `hyprctl dispatch workspace N` from the shell hits the same Lua wrapper and fails identically, so a `Process` fallback is not a way out. Native `workspace.activate()` also works, but only for workspaces that already exist (useless for the bar's persistent 1–4 placeholders). Dispatcher syntax ground truth is the user's own `~/hypr-dotfiles/hypr/.config/hypr/keybinds.lua` (workspace switching is `hl.dsp.focus({ workspace = i })`; `hl.dsp.workspace` is a table, not callable). Note: `Hyprland.workspaces`' `valuesChanged` does **not** fire when only the active flag changes — verify switches with `hyprctl activeworkspace`, not with the model signal.
- `Mpris` player fields are `trackTitle` / `trackArtist` / `trackArtUrl` — there are no plain `title` / `artist` properties, and they read `undefined` until a track is loaded.
- `Quickshell.screens` is a JS-array-like list; use `.length` / `[i]`, not `.count`.
- `Quickshell.env()` is a **method**, not a property.
- `Timer` and `Component` need an explicit `import QtQml` — `import Quickshell` alone does not provide them.
- `PanelWindow`: use `implicitHeight`, not `height` (the latter is deprecated and warns). `exclusiveZone` and `ExclusionMode.Ignore` both exist.
- **Children of a `PanelWindow` do not auto-fill its content item.** A plain `Item` declared inside one stays 0x0 unless it sets `anchors.fill: parent` (or explicit width/height). Anchors that reference `parent` then resolve against a zero-size parent — `horizontalCenter` parks the child at negative x, half off-screen. `Launcher.qml` sidesteps this by making the `PanelWindow` itself the component root; `Bar.qml` uses `anchors.fill: parent`. Verify any new module's root geometry at runtime before trusting it.
- `SystemClock.Seconds` and `Variants` both exist as the scaffold uses them.

## QML import rules that bite here

- From `Modules/<Name>/<Name>.qml`, the Theme import is **`import "../../Theme"`** — two levels up. `../Theme` silently resolves to the nonexistent `Modules/Theme`.
- Every module directory needs its own `import "Modules/<Name>"` line in `shell.qml`; QML does not propagate imports.
- A directory containing a `qmldir` does **not** implicitly expose its sibling files as types. `Theme/qmldir` must declare `Colors 1.0 Colors.qml` or `Theme.qml`'s `Colors {}` reference fails with "Colors is not a type".
- `Launcher` must be instantiated once in `ShellRoot`, **not** inside the per-monitor `Variants` delegate (a `Component` accepts only one root object).

## Launcher

- `Modules/Launcher/Launcher.qml` replaces rofi drun. Toggle from Hyprland with `qs ipc call launcher toggle` (also `open` / `close`).
- TextInput → filter must use `onTextEdited: root.filter = input.text`. A `text: root.filter` binding is one-way and breaks on the first keystroke, so the list never filters.
- Keyboard: Up/Down wrap (rofi's `cycle: true`), Enter launches, Escape closes. Click outside the card dismisses; clicks on the card are swallowed by a `MouseArea`.
- Metrics mirror rofi's `config.rasi`: 500px card, radius 22, 7 visible rows, radius 12 selection, 30px icons.

## Git state

- Single branch `main`, no remote configured. No branch/PR/release conventions are encoded anywhere — ask before inventing them.
- As of this writing the tree is dirty: `AGENTS.md` is untracked and `shell.qml`, `Theme/{qmldir,Theme.qml}`, `Modules/Bar/Bar.qml`, and `Modules/Launcher/Launcher.qml` are modified (launcher implementation + the 0.3.2 API fixes). Nothing is committed yet.
