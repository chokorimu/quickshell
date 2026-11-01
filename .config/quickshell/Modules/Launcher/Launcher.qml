// Launcher.qml — app launcher (rofi drun replacement)
// toggle from hyprland:  qs ipc call launcher toggle
// metrics mirror rofi's config.rasi: 500px card, r22, 7 rows, r12 selection
import QtQml
import QtQuick
import Quickshell
import Quickshell.Io
import "../../Theme"

PanelWindow {
    id: root

    property bool open: false
    property string filter: ""
    property int selected: 0

    visible: root.open
    focusable: true
    exclusionMode: ExclusionMode.Ignore

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    color: "transparent"

    // ---- app list -------------------------------------------------------
    // DesktopEntries populates asynchronously; applicationsChanged is the
    // only reliable signal that the scan has finished.
    property var apps: []

    function reloadApps() {
        var all = DesktopEntries.applications.values
        var out = []
        for (var i = 0; i < all.length; i++) {
            var e = all[i]
            if (e.noDisplay) continue
            if (!e.name) continue
            out.push(e)
        }
        root.apps = out
        root.selected = 0
    }

    Component.onCompleted: reloadApps()

    Connections {
        target: DesktopEntries
        function onApplicationsChanged() { root.reloadApps() }
    }

    readonly property var filtered: {
        var f = root.filter.trim().toLowerCase()
        if (f.length === 0) return root.apps
        var out = []
        for (var i = 0; i < root.apps.length; i++) {
            if (root.apps[i].name.toLowerCase().indexOf(f) !== -1)
                out.push(root.apps[i])
        }
        return out
    }

    onFilterChanged: root.selected = 0

    // ---- actions --------------------------------------------------------
    function reset() {
        root.filter = ""
        root.selected = 0
        input.text = ""
    }

    function close() {
        root.open = false
        root.reset()
    }

    function launch(entry) {
        if (!entry) return
        // DesktopEntry.command is a QStringList — hand it to Process as-is.
        proc.command = entry.command
        proc.running = true
        root.close()
    }

    Process { id: proc }

    // ---- ipc ------------------------------------------------------------
    IpcHandler {
        target: "launcher"
        function toggle(): void {
            if (root.open) root.close()
            else { root.reset(); root.open = true; input.forceActiveFocus() }
        }
        function open(): void {
            root.reset()
            root.open = true
            input.forceActiveFocus()
        }
        function close(): void { root.close() }
    }

    // ---- ui -------------------------------------------------------------
    // click outside the card dismisses
    MouseArea {
        anchors.fill: parent
        onClicked: root.close()
    }

    Rectangle {
        anchors.centerIn: parent
        width: 500
        height: card.height + 20
        color: Theme.barBackground
        radius: 22

        // swallow clicks so they don't reach the dismiss layer
        MouseArea { anchors.fill: parent }

        Column {
            id: card
            anchors.centerIn: parent
            width: 480
            spacing: 0

            // search field
            Rectangle {
                width: parent.width
                height: 44
                radius: 12
                color: Theme.barHighlight

                TextInput {
                    id: input
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    verticalAlignment: Text.AlignVCenter
                    color: Theme.barForeground
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.launcherFontSize
                    selectByMouse: true
                    persistentSelection: true

                    // push user input into the filter; reset() clears both sides
                    onTextEdited: root.filter = input.text

                    Text {
                        anchors.fill: parent
                        verticalAlignment: Text.AlignVCenter
                        text: "Search Apps..."
                        color: Theme.barDim
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.launcherFontSize
                        visible: input.text.length === 0
                    }

                    Keys.onPressed: function(event) {
                        var n = root.filtered.length
                        if (event.key === Qt.Key_Escape) {
                            root.close()
                            event.accepted = true
                        } else if (event.key === Qt.Key_Down && n > 0) {
                            root.selected = (root.selected + 1) % n
                            list.positionViewAtIndex(root.selected, ListView.Contain)
                            event.accepted = true
                        } else if (event.key === Qt.Key_Up && n > 0) {
                            root.selected = (root.selected - 1 + n) % n
                            list.positionViewAtIndex(root.selected, ListView.Contain)
                            event.accepted = true
                        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            if (n > 0) root.launch(root.filtered[root.selected])
                            event.accepted = true
                        }
                    }
                }
            }

            Item { width: parent.width; height: 10 }

            // results — 7 visible rows, matching rofi's listview
            ListView {
                id: list
                width: parent.width
                height: Math.min(root.filtered.length, 7) * 40
                clip: true
                model: root.filtered
                currentIndex: root.selected
                highlightFollowsCurrentItem: false
                onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
                boundsBehavior: Flickable.StopAtBounds
                reuseItems: true

                delegate: MouseArea {
                    required property int index
                    required property var modelData
                    width: list.width
                    height: 40
                    onClicked: root.launch(modelData)

                    Rectangle {
                        anchors.fill: parent
                        radius: 12
                        color: index === root.selected ? Theme.barInk : "transparent"
                    }

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 5
                        anchors.rightMargin: 5
                        spacing: 10

                        Image {
                            width: 30
                            height: 30
                            anchors.verticalCenter: parent.verticalCenter
                            sourceSize: Qt.size(30, 30)
                            fillMode: Image.PreserveAspectFit
                            source: Quickshell.iconPath(modelData.icon, "application-x-executable")
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.name
                            color: index === root.selected ? Theme.barOnInk : Theme.barForeground
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.launcherFontSize
                            elide: Text.ElideRight
                            width: list.width - 60
                        }
                    }
                }
            }

            Item { width: parent.width; height: 10 }
        }
    }
}
