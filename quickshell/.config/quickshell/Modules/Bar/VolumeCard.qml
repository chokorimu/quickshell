// VolumeCard.qml — the island's second menu: per-app volume.
//
// Lives inside the same pop-open card as the media page; Bar.qml gates
// which page is visible. Master sink row on top (the Audio service),
// then one row per playback stream from AppAudio — pavucontrol's
// playback tab, in the shell's own language. The list scrolls when more
// apps are playing than the card can hold.
//
// Layout follows the reference design: the header mark + "Volume"
// title left-aligned past the menu column strip, then the rows. The
// strip is 56px wide, and the content keeps an 80px left margin, so
// nothing rides it.
import QtQml
import QtQuick
import Quickshell
import "../../Services"
import "../../Theme"

Item {
    id: volumeCard

    // title row — header mark + "Volume", left-aligned. The 80px
    // margin clears the menu column strip (56 wide), so nothing rides
    // it.
    Row {
        id: titleRow
        anchors.top: parent.top
        anchors.topMargin: 28
        anchors.left: parent.left
        anchors.leftMargin: 80
        spacing: 12

        HeaderIcon {
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "VOLUME"
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
        label: "Master volume"
        streamId: -1
        value: Audio.volume
        muted: Audio.muted
    }

    // app streams
    ListView {
        id: appList
        anchors.top: masterRow.bottom
        anchors.topMargin: 4
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
            // appList.width, never ListView.width: with no id on the view,
            // `ListView` resolves to the TYPE object (typeof "object"), whose
            // .width is undefined — the delegate's width silently becomes 0
            // and the row's slider anchors collapse to nothing (left 132
            // against right -82), leaving the app name with no slider. No
            // error is logged, which is how it shipped.
            width: appList.width
            height: 40
            label: modelData.app
            streamId: modelData.id
            value: modelData.volume
            muted: modelData.muted
        }
    }
}
