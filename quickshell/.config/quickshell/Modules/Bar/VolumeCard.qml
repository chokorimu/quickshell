// VolumeCard.qml — the island's second menu: per-app volume.
//
// Lives inside the same pop-open card as the media page; Bar.qml gates
// which page is visible. Master sink row on top (the Audio service),
// then one row per playback stream from AppAudio — pavucontrol's
// playback tab, in the shell's own language. The list scrolls when more
// apps are playing than the card can hold.
//
// Layout follows the reference design: a speaker glyph + "Volume" title
// left-aligned past the card's lime accent strip, then the rows. The
// strip is 8px wide and the content keeps a 48px left margin, so
// nothing ever rides the accent.
import QtQml
import QtQuick
import Quickshell
import "../../Services"
import "../../Theme"

Item {
    id: volumeCard

    // title row — speaker glyph + "Volume", left-aligned. The 56px
    // margin clears the tab column's block (ends at x=40) with 16px
    // to spare.
    Row {
        id: titleRow
        anchors.top: parent.top
        anchors.topMargin: 28
        anchors.left: parent.left
        anchors.leftMargin: 56
        spacing: 12

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "\uF028" // speaker
            color: Theme.barForeground
            font.family: Theme.iconFont
            font.pixelSize: 20
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "Volume"
            color: Theme.barForeground
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
        anchors.leftMargin: 56
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
        anchors.leftMargin: 56
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
