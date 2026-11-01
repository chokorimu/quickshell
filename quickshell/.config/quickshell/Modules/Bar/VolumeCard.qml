// VolumeCard.qml — the island's second menu: per-app volume.
//
// Lives inside the same swipe-down card as the media page; Bar.qml gates
// which page is visible. Master sink row on top (the Audio service), a
// divider, then one row per playback stream from AppAudio — pavucontrol's
// playback tab, in the shell's own language. The list scrolls when more
// apps are playing than the card can hold.
import QtQml
import QtQuick
import Quickshell
import "../../Services"
import "../../Theme"

Item {
    id: volumeCard

    Text {
        id: title
        anchors.top: parent.top
        anchors.topMargin: 20
        anchors.horizontalCenter: parent.horizontalCenter
        text: "Volumes"
        color: Theme.barForeground
        font.family: Theme.barFontFamily
        font.pixelSize: 20
        font.weight: Font.DemiBold
    }

    // master sink
    VolumeRow {
        id: masterRow
        anchors.top: title.bottom
        anchors.topMargin: 14
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 28
        anchors.rightMargin: 28
        height: 40
        label: "System"
        streamId: -1
        value: Audio.volume
        muted: Audio.muted
    }

    Rectangle {
        id: divider
        anchors.top: masterRow.bottom
        anchors.topMargin: 12
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 28
        anchors.rightMargin: 28
        height: 1
        color: Theme.barHighlight
    }

    // app streams
    Item {
        anchors.top: divider.bottom
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right

        Text {
            anchors.centerIn: parent
            text: "no apps playing audio"
            color: Theme.barDim
            font.family: Theme.barFontFamily
            font.pixelSize: 14
            visible: AppAudio.streams.length === 0
        }

        ListView {
            anchors.fill: parent
            anchors.topMargin: 8
            anchors.bottomMargin: 12
            clip: true
            spacing: 4
            model: AppAudio.streams
            delegate: VolumeRow {
                required property var modelData
                width: ListView.width
                height: 40
                label: modelData.app
                streamId: modelData.id
                value: modelData.volume
                muted: modelData.muted
            }
        }
    }
}
