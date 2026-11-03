// StatCell.qml — one readout cell on the usage page: a small label, a
// big percentage, a thin meter and a dim line of absolute numbers.
//
// The meter is the slider's proportions without the handle — a 5px
// track on cardHighlight with the fill in the card's accent, so a
// live reading ties back to the tab that opened the page. When the
// backing service reports unavailable the value drops to a dim
// "n/a", the meter empties and the sub-line carries the reason —
// nvidia-smi is the case that matters: a machine without an NVIDIA
// dGPU gets an absent GPU row rather than a broken one.
//
// No MouseArea in here: the page is read-only, and a hover-enabled
// area would steal cardZone's hover in Bar.qml and collapse the
// island under a resting cursor.
import QtQml
import QtQuick
import "../../Theme"

Item {
    id: statCell

    property string label: ""
    // 0..1
    property real fraction: 0
    property bool available: true
    property string valueText: ""
    property string subText: ""

    readonly property real shown: Math.max(0, Math.min(1, fraction))

    Text {
        id: labelText
        anchors.left: parent.left
        anchors.top: parent.top
        text: statCell.label
        color: Theme.cardDim
        font.family: Theme.barFontFamily
        font.pixelSize: 12
    }

    Text {
        id: valueLabel
        anchors.left: parent.left
        anchors.top: labelText.bottom
        anchors.topMargin: 8
        text: statCell.available ? statCell.valueText : "n/a"
        color: statCell.available ? Theme.cardForeground : Theme.cardDim
        font.family: Theme.barFontFamily
        font.pixelSize: 32
        font.weight: Font.DemiBold
    }

    // the meter — track on cardHighlight, fill in the accent, the
    // volume slider's 5px proportions with no handle
    Rectangle {
        id: meter
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: valueLabel.bottom
        anchors.topMargin: 16
        height: 5
        radius: 2.5
        color: Theme.cardHighlight

        Rectangle {
            width: parent.width * (statCell.available ? statCell.shown : 0)
            height: parent.height
            radius: 2.5
            color: Theme.cardAccent
        }
    }

    Text {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: meter.bottom
        anchors.topMargin: 10
        text: statCell.available ? statCell.subText : (statCell.subText.length > 0 ? statCell.subText : "unavailable")
        color: Theme.cardDim
        font.family: Theme.barFontFamily
        font.pixelSize: 12
        elide: Text.ElideRight
    }
}
