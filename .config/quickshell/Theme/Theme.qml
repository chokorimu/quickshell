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

    // typography
    readonly property string fontFamily: "monospace"
    readonly property int fontSize: 13
    readonly property int launcherFontSize: 16
}
