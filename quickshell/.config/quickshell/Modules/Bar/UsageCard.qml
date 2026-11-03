// UsageCard.qml — the island's second menu: system usage.
//
// Same card and same pop as the media, volume, theme, capture and
// session pages; reached by hovering the second tab button in the
// column. Two rows of readouts: CPU and memory on top, GPU / disk /
// battery underneath. Every cell is a StatCell — label, big
// percentage, thin meter, dim line of absolute numbers.
//
// Cpu, Gpu and Disk are page-only services in the Brightness
// mould: they poll only while this page is on screen, so the 2s/5s
// forks cost nothing while the card is closed. `active` flips with
// the page's visibility and refresh() runs on the way in, so the
// first frame already has real numbers instead of zeros. Memory
// and Battery are reused ungated — Memory already polls for the
// bar's readout and Battery is push-based off UPower.
//
// The rows are anchored, not a Column: a Column gives its children
// height but never width, and anchors are illegal on a positioner's
// direct child anyway. Row 1 is two 240px cells, row 2 three 156px
// cells, both 492px across — the content width between the 80px
// left margin (clearing the menu column strip) and the 28px right
// one, with a 12px gap in each row.
//
// No MouseArea in here takes hover: the page is read-only, and a
// hover-enabled area would steal cardZone's hover in Bar.qml and
// collapse the island under a resting cursor.
import QtQml
import QtQuick
import Quickshell
import "../../Services"
import "../../Theme"

Item {
    id: usageCard

    // The three page-only services poll only while this page is on
    // screen — they have no other consumer, and the card is usually
    // closed. refresh() on the way in so the first frame shows real
    // numbers rather than the zeroed defaults.
    onVisibleChanged: {
        Cpu.active = visible
        Gpu.active = visible
        Disk.active = visible
        if (visible) {
            Cpu.refresh()
            Gpu.refresh()
            Disk.refresh()
        }
    }

    // title row — header mark + "Usage", left-aligned. The 80px
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
            text: "// USAGE"
            color: Theme.cardForeground
            font.family: Theme.barFontFamily
            font.pixelSize: 20
            font.weight: Font.DemiBold
        }
    }

    // ---- row 1: CPU and memory ----------------------------------------
    // Two 240px cells across the 492px content width with a 12px gap.
    Row {
        id: firstRow
        anchors.top: titleRow.bottom
        anchors.topMargin: 28
        anchors.left: parent.left
        anchors.leftMargin: 80
        anchors.right: parent.right
        anchors.rightMargin: 28
        spacing: 12

        StatCell {
            width: 240
            height: 132
            label: "CPU"
            available: Cpu.available
            fraction: Cpu.fraction
            valueText: Math.round(Cpu.fraction * 100) + "%"
            subText: "system-wide"
        }

        StatCell {
            width: 240
            height: 132
            label: "Memory"
            available: Memory.available
            fraction: Memory.fraction
            valueText: Math.round(Memory.fraction * 100) + "%"
            subText: Memory.available ? Memory.usedGb.toFixed(1) + " / " + Memory.totalGb.toFixed(1) + " GiB" : ""
        }
    }

    // ---- row 2: GPU, disk, battery ------------------------------------
    // Three 156px cells across the same width with two 12px gaps.
    Row {
        id: secondRow
        anchors.top: firstRow.bottom
        anchors.topMargin: 20
        anchors.left: parent.left
        anchors.leftMargin: 80
        anchors.right: parent.right
        anchors.rightMargin: 28
        spacing: 12

        StatCell {
            width: 156
            height: 132
            label: "GPU"
            available: Gpu.available
            fraction: Gpu.fraction
            valueText: Math.round(Gpu.fraction * 100) + "%"
            subText: Gpu.available ? Gpu.usedVramGb.toFixed(1) + " / " + Gpu.totalVramGb.toFixed(1) + " GiB" : ""
        }

        StatCell {
            width: 156
            height: 132
            label: "Disk"
            available: Disk.available
            fraction: Disk.fraction
            valueText: Math.round(Disk.fraction * 100) + "%"
            subText: Disk.available ? Disk.usedGb.toFixed(1) + " / " + Disk.totalGb.toFixed(1) + " GiB" : ""
        }

        StatCell {
            width: 156
            height: 132
            label: "Battery"
            available: Battery.present
            fraction: Battery.percentage
            valueText: Math.round(Battery.percentage * 100) + "%"
            subText: Battery.present ? (Battery.charging ? "charging" : "on battery") : "no battery"
        }
    }
}
