// Notifications.qml — notification popups
// TODO: hook into Quickshell.Services.Notifications, stack popups top-right
import QtQuick
import Quickshell

PanelWindow {
    visible: false
    anchors {
        top: true
        right: true
    }
    width: 360
    height: 400
    color: "transparent"
}
