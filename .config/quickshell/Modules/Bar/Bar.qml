// Bar.qml — top bar: workspaces + clock
import QtQuick
import Quickshell
import Quickshell.Hyprland
import "../../Theme"

Item {
    id: root

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }

    // left: hyprland workspaces
    Row {
        anchors.left: parent.left
        anchors.leftMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6

        Repeater {
            model: Hyprland.workspaces
            Rectangle {
                required property var modelData
                implicitWidth: 26
                implicitHeight: 26
                radius: 8
                color: modelData.active ? Theme.accent : "transparent"

                Text {
                    anchors.centerIn: parent
                    text: modelData.id
                    color: modelData.active ? Theme.barColor : Theme.muted
                    font.pixelSize: Theme.fontSize
                    font.family: Theme.fontFamily
                }
            }
        }
    }

    // right: clock
    Text {
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        text: Qt.formatDateTime(clock.date, "ddd MMM d   hh:mm:ss")
        color: Theme.text
        font.pixelSize: Theme.fontSize
        font.family: Theme.fontFamily
    }
}
