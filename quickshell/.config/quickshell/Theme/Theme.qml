// Theme.qml — singleton. import with `import "Theme"` (declared in Theme/qmldir).
import QtQuick
import Quickshell
import Quickshell.Io

pragma Singleton

Singleton {
    id: root

    readonly property Colors _colors: Colors {}

    // bar
    property color barColor: _colors.base
    property color barText: _colors.text

    // semantic
    property color accent: _colors.accent
    property color text:   _colors.text
    property color muted:  _colors.muted
    property color urgent: _colors.urgent
    property color surface: _colors.surface

    // ---- bar palette ----------------------------------------------------
    // Fixed palettes. These live here rather than in Colors.qml because
    // matugen overwrites Colors.qml on every wallpaper change, which would
    // recolour the bar the moment a palette is regenerated.
    // Light pill — pure white. The island card is the dark surface
    // against it (see cardBackground below), and the menu column
    // strip takes this same white so the bar's material reads as
    // extending down into the card. Text is deliberately
    // near-black — a white surface with the old light-gray text
    // would be unreadable.
    readonly property color fixedBarBg:      "#ffffff"
    readonly property color fixedBarSurface: "#e6e6e9"
    readonly property color fixedBarText:    "#1b1b1f"
    readonly property color fixedBarMuted:   "#8e8e93"
    readonly property color fixedBarUrgent:  "#c0392b"
    // near-black for the inverted workspace pill inside the white bar pill
    readonly property color fixedBarInk:     "#1b1b1f"
    // label color on those ink fills — white on the near-black
    readonly property color fixedBarOnInk:   "#ffffff"

    // Dark pill — deep charcoal, hardcoded for the same reason. The
    // workspace pill and the transport buttons keep the inverted
    // language: barInk stays DARKER than the bar (the light palette's
    // near-black-on-white, greyed down), and barOnInk is the label
    // color that sits on those ink fills.
    readonly property color fixedDarkBarBg:      "#222226"
    readonly property color fixedDarkBarSurface: "#323238"
    readonly property color fixedDarkBarText:    "#e8e8ea"
    readonly property color fixedDarkBarMuted:   "#9a9aa0"
    readonly property color fixedDarkBarUrgent:  "#e05252"
    // darker than the bar — the inverted fills stay the dark element
    // inside the lighter surface
    readonly property color fixedDarkBarInk:     "#16161a"
    readonly property color fixedDarkBarOnInk:   "#e8e8ea"

    // Island surfaces. The card is lightened a step above the pill
    // surface so a control sitting on the card — the theme-mode
    // switch's track — can carry its own background and read against
    // it; at the old value the track was the same color as the card
    // and invisible. The pill surface keeps the older, darker value:
    // the workspace pill sits on the bar, where the inverted language
    // wants it darker than the bar, and the theme-mode track sits on
    // the card, where it now reads as one step down from the card.
    readonly property color fixedCardBgDark:  "#2a2a30"
    readonly property color fixedCardBgLight: "#f0f0f3"
    readonly property color fixedPillDark:  "#1c1c20"
    readonly property color fixedPillLight: "#e2e2e6"

    // ---- theme mode -----------------------------------------------------
    // auto / light / dark, picked from the island's Theme page. The
    // choice is written to a state file so it survives a reboot.
    //
    // PersistentProperties is NOT an option here: in 0.3.2 it only
    // spans hot reloads. Probed — it never writes a state file at all
    // (no ~/.local/state/quickshell entry appears, and a fresh process
    // comes back with the default), so a reboot would lose the mode.
    // FileView does persist, and it is what the avatar and the config
    // readers already use.
    //
    // The state file lives in ~/.local/state rather than
    // ~/.config/quickshell, which is this repo through stow — a file
    // written there would land in git as an untracked artifact.
    readonly property string modePath: Quickshell.env("HOME")
        + "/.local/state/quickshell/theme-mode"

    FileView {
        id: modeFile
        path: root.modePath
        // A five-byte local file, and the singleton is constructed
        // while the shell loads, so the blocking read costs
        // microseconds and the first frame paints on the persisted
        // theme instead of flashing the default.
        blockLoading: true
        // A missing file is the normal first boot. Errors stay quiet
        // so the log is not carrying a load failure on every fresh
        // start, and the file is created on the spot holding the
        // current mode — the state is explicit from then on rather
        // than only appearing once the switch is first used.
        printErrors: false
        onLoadFailed: modeFile.setText(root.themeMode)
    }

    // Read once, at construction: text() blocks until the load has
    // resolved, so the first frame paints on the persisted theme
    // rather than flashing the default. A missing, empty or
    // unrecognised value leaves the mode on auto. This is a plain
    // assignment rather than a binding on purpose — a binding
    // re-evaluates when the load settles and emits a change signal
    // even when the value is unchanged, which would rewrite the file
    // on every boot.
    property string themeMode: "auto"

    Component.onCompleted: {
        var t = modeFile.text().trim()
        if (t === "light" || t === "dark")
            root.themeMode = t
    }

    // Every change after that is written straight back. The content
    // check keeps the boot-time assignment from rewriting the file
    // with the value it already holds. A first boot with no file
    // creates one from onLoadFailed above, so this only ever fires
    // for a real change.
    onThemeModeChanged: if (modeFile.text().trim() !== root.themeMode)
        modeFile.setText(root.themeMode)

    // auto's source: matugen's generated palette. _colors.base is a
    // hex string (Colors.qml is matugen's output), so it goes through
    // a color property to get at the channels; the perceived
    // brightness split at 0.5 picks the pill that matches the
    // generated palette's weight.
    readonly property color matugenBase: _colors.base
    readonly property bool matugenIsDark: (0.299 * matugenBase.r
        + 0.587 * matugenBase.g + 0.114 * matugenBase.b) < 0.5

    // The fixed palette's side. light and dark pin it outright; auto
    // follows matugen's palette when the matugen switch is on and
    // falls back to the dark pill otherwise (LO's call). matugen
    // still wins over all three when barUseMatugen is on — the
    // derived bar* properties below read it first.
    readonly property bool darkMode: themeMode === "light" ? false
        : themeMode === "dark" ? true
        : (barUseMatugen ? matugenIsDark : true)

    // Flip to true once the matugen toggle UI exists. Bar.qml only ever
    // references the derived properties below, so switching is a
    // one-line change here rather than a rewrite of the bar.
    readonly property bool barUseMatugen: false

    readonly property color barBackground: barUseMatugen ? barColor   : (darkMode ? fixedDarkBarBg      : fixedBarBg)
    readonly property color barHighlight:  barUseMatugen ? accent     : (darkMode ? fixedDarkBarSurface : fixedBarSurface)
    readonly property color barForeground: barUseMatugen ? barText    : (darkMode ? fixedDarkBarText    : fixedBarText)
    readonly property color barDim:        barUseMatugen ? muted      : (darkMode ? fixedDarkBarMuted   : fixedBarMuted)
    readonly property color barUrgent:     barUseMatugen ? urgent     : (darkMode ? fixedDarkBarUrgent  : fixedBarUrgent)
    readonly property color barInk:        barUseMatugen ? barColor   : (darkMode ? fixedDarkBarInk     : fixedBarInk)
    readonly property color barOnInk:      barUseMatugen ? barText    : (darkMode ? fixedDarkBarOnInk   : fixedBarOnInk)

    // ---- workspace pill ------------------------------------------------
    // Shares the pill surface (fixedPill*): deep charcoal in dark
    // mode, light gray in light mode. The active circle takes
    // barBackground — lighter than the surface in dark mode, white in
    // light mode — with a barForeground number, the one label color
    // that reads on both fills.
    readonly property color barWorkspacePill: darkMode ? fixedPillDark : fixedPillLight
    // inactive numbers on the pill — the dark palette's muted gray, or a
    // deeper gray that survives on the light surface (barDim's light
    // value washes out against light gray)
    readonly property color barWorkspaceDim:  darkMode ? fixedDarkBarMuted : "#6e6e73"

    // card accent — the saturated yellow fill on the island tab
    // column's selected button. Fixed in both palettes, like
    // screenCornerColor: it is an accent, not a surface. One yellow
    // with launcherSelection below — the same value, so every accent
    // in the shell reads as one system.
    readonly property color cardAccent: "#e6e600"
    // label color on the accent — the selected button's glyph. Fixed
    // for the same reason cardAccent is: the accent never flips.
    readonly property color cardAccentOn: "#1b1b1f"
    // streaming live — the second live state on the capture page's
    // record row. Fixed in both palettes for the same reason
    // cardAccent is: it is a state color, not palette content, and
    // one blue reads on both card surfaces. #2563eb against white is
    // 4.9:1, so the label passes AA on the fill in either theme.
    readonly property color cardStream: "#2563eb"
    // label on the streaming fill — white in both palettes, since the
    // fill is dark enough to carry it everywhere.
    readonly property color cardStreamOn: "#ffffff"
    // card surface — the island surface, lightened a step above the
    // pill surface so a control on the card can carry its own
    // background (see fixedCardBg* above). The matugen path keeps the
    // card on the bar color (no inversion is computable from an
    // arbitrary palette).
    readonly property color cardBackground: barUseMatugen ? barColor : (darkMode ? fixedCardBgDark : fixedCardBgLight)
    // the theme-mode switch's track on the card — the workspace
    // pill's own surface, one step darker than the card so the track
    // reads. Same material, same value, different home.
    readonly property color cardPill: darkMode ? fixedPillDark : fixedPillLight
    // card content palette — flips with the card surface:
    // light-on-dark in the dark palette, dark-on-light in the
    // light one.
    readonly property color cardForeground: darkMode ? "#e8e8ea" : "#1b1b1f"
    readonly property color cardDim:       darkMode ? "#9a9aa0" : "#6e6e73"
    // subtle surface on the card — slider track, art circle
    readonly property color cardHighlight: darkMode ? "#3a3a40" : "#d2d2d6"
    // inverted fills on the card. The transport circles used to take
    // these — a slab of the card's opposite color — until they moved
    // to the workspace pill's own surface (cardPill); nothing uses
    // them now, but the inversion is the natural pair to cardOnInk
    // so they stay defined.
    readonly property color cardInk:       darkMode ? "#e8e8ea" : "#1b1b1f"
    readonly property color cardOnInk:     cardBackground

    // power-cell hover — a soft inversion: light on the dark card,
    // dark on the light one, each value the other palette's
    // cardHighlight. The fill used to be light in both themes because
    // the hold was a black wipe sweeping the button, and its leading
    // edge vanished against a dark fill (1.7:1 on the resting
    // cardHighlight); the hold is a ring now, traced on the card
    // outside the button, so nothing constrains the fill to stay light
    // and it can invert.
    readonly property color cardHover:   darkMode ? "#d2d2d6" : "#3a3a40"
    // content on the hover fill — flips with it, since the fill it
    // sits on flips: near-black on the light fill in the dark palette,
    // near-white on the dark fill in the light one.
    readonly property color cardHoverOn: darkMode ? "#1b1b1f" : "#e8e8ea"

    // launcher selection — the active row's fill. Fixed in both
    // palettes like cardAccent, and the same value as it: one
    // saturated yellow across the shell, deliberately not flipping
    // with darkMode or following matugen. Near-black label for
    // contrast on the yellow.
    readonly property color launcherSelection:   "#e6e600"
    readonly property color launcherSelectionOn: "#1b1b1f"
    // launcher search — the static label block beside the input
    // field. Inverted against the palette at LO's request: black in
    // the light theme, white in the dark one, with the label knocked
    // out in the opposite. Tied to darkMode like the rest of the
    // fixed card palette; matugen computes no inversion.
    readonly property color launcherSearchLabel:   darkMode ? "#ffffff" : "#000000"
    readonly property color launcherSearchLabelOn: darkMode ? "#000000" : "#ffffff"

    // typography
    readonly property string fontFamily: "monospace"
    readonly property string barFontFamily: "Montserrat Semibold"
    // Nerd Font for status glyphs (bar/OSD icons). Set explicitly on each
    // glyph Text — the bar's UI font is not an NF family, so inheriting it
    // would render every glyph as tofu. Verified to cover the Font Awesome
    // (f000-f381) and Material (f0001-f1af0) ranges.
    readonly property string iconFont: "JetBrainsMonoNL Nerd Font"
    readonly property int fontSize: 16
    readonly property int barFontSize: 16
    readonly property int barFontSizeSmall: 12
    readonly property int launcherFontSize: 16

    // Screen corners. No compositor rounds the physical screen — Modules/Corners
    // paints the four corner cutouts at the Overlay layer, so the color has to
    // match the wallpaper to blend (black is the safe default on dark setups).
    // screenCornersEnabled is the future off switch: flip it here, or bind it
    // to a toggle later.
    readonly property bool screenCornersEnabled: true
    readonly property int screenCornerRadius: 24
    readonly property color screenCornerColor: "#000000"
}
