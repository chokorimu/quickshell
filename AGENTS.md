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

- `.config/quickshell/shell.qml` is the only entrypoint (`ShellRoot`). One `PanelWindow` per monitor via `Variants { model: Quickshell.screens }`, `implicitHeight: 36`, `exclusiveZone: implicitHeight`.
- `Modules/Bar` (workspaces + clock) and `Modules/Launcher` (rofi drun replacement) are live. `Modules/Notifications`, `Modules/OSD`, `Modules/Session` are still `visible: false` stubs whose intent lives in their `// TODO:` header comments.
- `Services/Matugen.qml` is a `pragma Singleton` but is imported and instantiated **nowhere**. It is dead code until something wires it up — don't assume it runs.

## Theme singleton — the non-obvious part

- `Theme/qmldir` is what registers the singleton (`singleton Theme 1.0 Theme.qml`) and must also declare `Colors 1.0 Colors.qml`. From `shell.qml` you write `import "Theme"`; from `Modules/<Name>/` you need `import "../../Theme"` (see the import section below).
- `Theme.qml` and `Services/Matugen.qml` both use `pragma Singleton` with root type `Singleton` from `import Quickshell`. Follow that shape.
- `Theme/Colors.qml` holds raw hex values (catppuccin-mocha defaults) and is the file matugen is meant to overwrite. Hand-edits there will not survive a palette regeneration.
- `Notifications`, `OSD`, and `Session` still hardcode `#1e1e2e` instead of referencing `Theme.barColor`. Replace those with `Theme` properties when fleshing the stubs out.

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
- `Quickshell.screens` is a JS-array-like list; use `.length` / `[i]`, not `.count`.
- `Quickshell.env()` is a **method**, not a property.
- `Timer` and `Component` need an explicit `import QtQml` — `import Quickshell` alone does not provide them.
- `PanelWindow`: use `implicitHeight`, not `height` (the latter is deprecated and warns). `exclusiveZone` and `ExclusionMode.Ignore` both exist.
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
