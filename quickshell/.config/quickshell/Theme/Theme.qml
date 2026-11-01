// Theme.qml — singleton. import with `import "Theme"` (declared in Theme/qmldir).
import QtQuick
import Quickshell

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
    // Light pill. Text is deliberately near-black — a white surface with the
    // old light-gray text would be unreadable.
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
    readonly property color fixedDarkBarBg:      "#1a1a1c"
    readonly property color fixedDarkBarSurface: "#2a2a2e"
    readonly property color fixedDarkBarText:    "#e8e8ea"
    readonly property color fixedDarkBarMuted:   "#9a9aa0"
    readonly property color fixedDarkBarUrgent:  "#e05252"
    // darker than the bar — the inverted workspace pill and transport
    // buttons stay the dark element inside the lighter surface
    readonly property color fixedDarkBarInk:     "#101012"
    readonly property color fixedDarkBarOnInk:   "#e8e8ea"

    // TEMPORARY dark-mode toggle — flips the fixed palette between the
    // light and dark pills. Click the "//" prefix in the bar to flip it.
    // Moves to a proper menu later; the matugen path below is untouched
    // and still wins when barUseMatugen is on.
    property bool darkMode: false

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
