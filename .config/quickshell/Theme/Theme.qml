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
    // Fixed dark gray. These live here rather than in Colors.qml because
    // matugen overwrites Colors.qml on every wallpaper change, which would
    // recolour the bar the moment a palette is regenerated.
    // White pill. Text is deliberately near-black — a white surface with the
    // old light-gray text would be unreadable.
    readonly property color fixedBarBg:      "#ffffff"
    readonly property color fixedBarSurface: "#e6e6e9"
    readonly property color fixedBarText:    "#1b1b1f"
    readonly property color fixedBarMuted:   "#8e8e93"
    readonly property color fixedBarUrgent:  "#c0392b"

    // Flip to true once the matugen toggle UI exists. Bar.qml only ever
    // references the four derived properties below, so switching is a
    // one-line change here rather than a rewrite of the bar.
    readonly property bool barUseMatugen: false

    readonly property color barBackground: barUseMatugen ? barColor   : fixedBarBg
    readonly property color barHighlight:  barUseMatugen ? accent     : fixedBarSurface
    readonly property color barForeground: barUseMatugen ? barText    : fixedBarText
    readonly property color barDim:        barUseMatugen ? muted      : fixedBarMuted
    readonly property color barUrgent:     barUseMatugen ? urgent     : fixedBarUrgent

    // typography
    readonly property string fontFamily: "monospace"
    readonly property int fontSize: 13
    readonly property int launcherFontSize: 16
}
