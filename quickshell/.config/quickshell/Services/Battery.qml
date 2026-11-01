// Battery.qml — battery state via the UPower service.
//
// Like Mpris, UPower initialises lazily; the Connections on UPower.devices is
// what makes the model populate. Prefers the real laptop battery over
// displayDevice, which can report ready:false with a zero percentage until the
// device list has been enumerated.
import QtQml
import QtQuick
import Quickshell
import Quickshell.Services.UPower

pragma Singleton

Singleton {
    id: root

    // UPowerDeviceState
    readonly property int stateUnknown: 0
    readonly property int stateCharging: 1
    readonly property int stateDischarging: 2
    readonly property int stateEmpty: 3
    readonly property int stateFull: 4
    readonly property int statePendingCharge: 5
    readonly property int statePendingDischarge: 6

    property var device: null
    property bool present: false
    property real percentage: 0 // 0..1
    property int state: root.stateUnknown
    property bool charging: false
    property bool onBattery: false

    signal updated()

    function pickDevice() {
        var ds = UPower.devices.values
        for (var i = 0; i < ds.length; i++) {
            if (ds[i].isLaptopBattery) {
                root.device = ds[i]
                return
            }
        }
        root.device = UPower.displayDevice
    }

    function sync() {
        var d = root.device
        if (!d) {
            root.present = false
            root.updated()
            return
        }
        root.present = !!d.isPresent
        root.percentage = d.percentage || 0
        root.state = d.state
        root.charging = (d.state === root.stateCharging || d.state === root.statePendingCharge)
        root.onBattery = UPower.onBattery
        root.updated()
    }

    // forces the lazy UPower service to populate
    Connections {
        target: UPower.devices
        function onValuesChanged() {
            root.pickDevice()
            root.sync()
        }
    }

    Connections {
        target: root.device
        function onPercentageChanged() { root.sync() }
        function onStateChanged() { root.sync() }
        function onIsPresentChanged() { root.sync() }
    }

    Component.onCompleted: {
        root.pickDevice()
        root.sync()
    }
}
