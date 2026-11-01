// VolumeRow.qml — one row in the volume card: name, slider, percent.
//
// streamId -1 is the master sink (Audio service); anything else is a
// playback stream (AppAudio). The slider is hand-rolled to match the
// shell's aesthetic — track, fill, riding handle, no Controls import.
//
// The slider keeps a local visual value while dragging. The service
// polls every 2s, and a read-back landing mid-drag would snap the
// handle back to the old value; `shown` prefers the local value until
// release. Commits are throttled to one per 100ms during the drag so
// the audio follows live without spawning a pactl per mouse-move
// event, and the final value is always committed on release.
import QtQml
import QtQuick
import Quickshell
import "../../Services"
import "../../Theme"

Item {
    id: row

    property string label: ""
    property int streamId: -1 // -1 = master sink
    property real value: 0
    property bool muted: false

    readonly property real maxValue: 1.5

    // local drag state — see the header comment
    property real visual: 0
    property bool dragging: false
    readonly property real shown: dragging ? visual : value
    readonly property real fraction: Math.max(0, Math.min(1, shown / maxValue))

    function commit(v) {
        if (row.streamId < 0)
            Audio.setVolume(v)
        else
            AppAudio.setVolume(row.streamId, v)
    }

    function nudge(delta) {
        row.commit(Math.max(0, Math.min(row.maxValue, row.shown + delta)))
    }

    function setFromX(x) {
        row.visual = Math.max(0, Math.min(1, x / slider.width)) * row.maxValue
        if (!writeThrottle.running) {
            row.commit(row.visual)
            writeThrottle.restart()
        }
    }

    Timer {
        id: writeThrottle
        interval: 100
    }

    // name
    Text {
        id: nameText
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: 120
        text: row.label
        color: row.muted ? Theme.cardDim : Theme.cardForeground
        font.family: Theme.barFontFamily
        font.pixelSize: 14
        elide: Text.ElideRight
    }

    // slider — the MouseArea is taller than the track so a drag that
    // drifts a few pixels vertically keeps tracking
    Item {
        id: slider
        anchors.left: nameText.right
        anchors.leftMargin: 12
        anchors.right: pctText.left
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        height: 24

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: 5
            radius: 2.5
            color: Theme.cardHighlight

            Rectangle {
                width: parent.width * row.fraction
                height: parent.height
                radius: 2.5
                color: row.muted ? Theme.cardHighlight : Theme.cardDim
            }
        }

        // handle rides the fill's edge — a horizontal rounded rectangle:
        // 32 wide against 8 tall, so the width is the long axis, with
        // radius 3 rounding the corners without pill-ing the ends off.
        // Clamped to the track: mid-range the handle centers on the
        // fill's edge, but at 0% and max its edge aligns with the
        // track's end instead of its center overhanging into the name
        // and percent margins.
        Rectangle {
            x: Math.max(0, Math.min(parent.width - width, parent.width * row.fraction - width / 2))
            anchors.verticalCenter: parent.verticalCenter
            width: 32
            height: 8
            radius: 3
            color: Theme.cardForeground
            visible: !row.muted
        }

        MouseArea {
            anchors.fill: parent
            onPressed: (mouse) => {
                row.dragging = true
                row.setFromX(mouse.x)
            }
            onPositionChanged: (mouse) => {
                if (row.dragging)
                    row.setFromX(mouse.x)
            }
            onReleased: {
                row.dragging = false
                row.commit(row.visual)
            }
            onWheel: (wheel) => row.nudge(wheel.angleDelta.y > 0 ? 0.05 : -0.05)
        }
    }

    // percentage — "muted" while muted. Right-aligned to the row's edge
    // now that the speaker glyph (which doubled as the mute toggle) is
    // gone; the slider absorbs the width the glyph used to reserve.
    Text {
        id: pctText
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: 48
        text: row.muted ? "muted" : Math.round(row.shown * 100) + "%"
        color: row.muted ? Theme.cardDim : Theme.cardForeground
        font.family: Theme.barFontFamily
        font.pixelSize: 13
        horizontalAlignment: Text.AlignRight
    }
}
