// VolumeCard.qml — the island's second menu: per-app volume.
//
// Lives inside the same pop-open card as the media page; Bar.qml gates
// which page is visible. Master sink row on top (the Audio service),
// then one row per playback stream from AppAudio — pavucontrol's
// playback tab, in the shell's own language. The list scrolls when more
// apps are playing than the card can hold.
//
// Layout follows the reference design: a speaker glyph + "Volume" title
// left-aligned past the menu column strip, then the rows. The strip
// is 56px wide with a 24px drop shadow, and the content keeps an
// 80px left margin, so nothing rides either.
import QtQml
import QtQuick
import Quickshell
import "../../Services"
import "../../Theme"

Item {
    id: volumeCard

    // title row — speaker glyph + "Volume", left-aligned. The 80px
    // margin clears the menu column strip (56 wide) plus its 24px
    // drop shadow, so nothing rides either.
    Row {
        id: titleRow
        anchors.top: parent.top
        anchors.topMargin: 28
        anchors.left: parent.left
        anchors.leftMargin: 80
        spacing: 12

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "\uF028" // speaker
            color: Theme.cardForeground
            font.family: Theme.iconFont
            font.pixelSize: 20
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "Volume"
            color: Theme.cardForeground
            font.family: Theme.barFontFamily
            font.pixelSize: 20
            font.weight: Font.DemiBold
        }
    }

    // master sink
    VolumeRow {
        id: masterRow
        anchors.top: titleRow.bottom
        anchors.topMargin: 20
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 80
        anchors.rightMargin: 28
        height: 40
        label: "System"
        streamId: -1
        value: Audio.volume
        muted: Audio.muted
    }

    // app streams
    ListView {
        anchors.top: masterRow.bottom
        anchors.topMargin: 8
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 16
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 80
        anchors.rightMargin: 28
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
