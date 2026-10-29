import QtQuick 2.3
import QtQuick.Layouts 1.1
import Hector.Controls 1.0
import Hector.MultiRobot 1.0
import Hector.Style 1.0

//! Displays the active robot's announced sensor values, one SensorValue per entry in
//! RobotManager.activeRobot.sensors. The list and every subscription rebuild when the
//! active robot or its announcement changes. Rendering is driven entirely by the
//! announced Sensor config (topic, field, unit, icon, prefix + hints); no sensor is
//! hardcoded here.
RowLayout {
    id: control

    //! Fallback stale timeout (ms) when a sensor announces no "timeout" hint.
    property int defaultTimeout: 5000

    Repeater {
        model: RobotManager.activeRobot ? RobotManager.activeRobot.sensors : []

        delegate: SensorValue {
            id: sensorValue

            property var sensor: modelData

            dangerous: source.dangerous
            icon: Style.icons[sensor.icon] || Style.icons.manometer
            unit: sensor.unit
            value: source.text
            visible: source.subscribed
            warn: source.warn

            SimpleToolTip {
                text: sensor.name + "\n" + sensor.topic
            }
            SensorValueSource {
                id: source
                defaultTimeout: control.defaultTimeout
                sensor: sensorValue.sensor
            }
        }
    }
}
