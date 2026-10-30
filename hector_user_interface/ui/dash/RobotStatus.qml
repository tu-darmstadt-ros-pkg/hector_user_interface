import QtQuick 2.3
import QtQuick.Controls.Basic 2.1
import QtQuick.Layouts 1.1
import Ros2 1.0
import Hector.Controls 1.0
import Hector.MultiRobot 1.0
import Hector.Style 1.0
import Hector.Utils 1.0
import "status"

Item {
    id: root
    implicitHeight: content.implicitHeight
    implicitWidth: content.implicitWidth

    // Content
    ColumnLayout {
        id: content
        anchors.fill: parent
        spacing: Units.pt(2)

        LaunchManagerStatus {
            Layout.fillWidth: true
            style: Style.activeStyle
        }
        Rectangle {
            Layout.fillWidth: true
            color: Style.activeStyle.primary.color
            height: Units.pt(16)

            AutoSizeText {
                id: autonomyStateText
                color: Style.getTextColor(Style.activeStyle.primary.color)
                margins: Units.pt(2)
                text: {
                    const mode = RobotManager.activeRobot ? RobotManager.activeRobot.operationMode : Robot.OperationMode.Unknown;
                    if (mode == Robot.OperationMode.Safe)
                        return "Safe";
                    if (mode == Robot.OperationMode.Teleoperation)
                        return "Teleoperation";
                    if (mode == Robot.OperationMode.Manipulation)
                        return "Manipulation";
                    if (mode == Robot.OperationMode.Autonomous)
                        return "Autonomous";
                    return "Unknown";
                }
            }
        }
        RobotDiagnosticsStatus {
            Layout.fillWidth: true
            Layout.preferredHeight: Units.pt(16)
        }
        ProgressWithText {
            property var batteries: RobotManager.activeRobot.status.batteries ?? []
            property real battery_level: RobotManager.activeRobot.status.battery_level ?? -1

            Layout.fillWidth: true
            backgroundColor: Style.battery.background
            foregroundColor: Style.battery.foregroundColor
            height: Units.pt(16)
            text: {
                const level = battery_level === -1 ? "" : battery_level + "%";
                const voltages = batteries.filter(b => !isNaN(b.voltage)).map(b => b.voltage.toFixed(1)).join(" · ");
                const voltage = voltages === "" ? "" : voltages + " V";
                if (level !== "" && voltage !== "")
                    return level + " | " + voltage;
                if (level !== "")
                    return level;
                if (voltage !== "")
                    return voltage;
                return "Unknown";
            }
            value: battery_level / 100
            visible: battery_level !== -1 || batteries.length > 0
        }

        //Latency
        Rectangle {
            Layout.fillWidth: true
            color: {
                const message = connSubscriber.message;
                // Explicit undefined checks: latency/packet_loss of 0 are valid (good) values
                if (!message || message.latency === undefined || message.packet_loss === undefined)
                    return Style.colors.status.warn;
                return Style.colors.status.ok;
            }
            height: Units.pt(16)

            AutoSizeText {
                property alias message: connSubscriber.message

                color: Style.getTextColor(parent.color)
                text: message ? message.latency + " ms | " + message.packet_loss + " %" : "No Connection Status"
            }
            Subscription {
                id: connSubscriber

                property var topicProperty: rviz && rviz.registerRosTopicProperty("Network Topic", "/processed_connectivity", "connectivity_monitor/NetworkInfo")

                topic: topicProperty.value
            }
        }

        // Subscription {
        //     id: connlossSubscriber
        //     property var topicProperty: rviz && rviz.registerRosTopicProperty("Connectivity Loss Navigation Topic", "/connectivity_loss_return_navigation_node/state", "connectivity_loss_return_navigation/ConnectivityLossReturnNavigationState")
        //     topic: topicProperty.value
        // }

        // ProgressWithText {
        //     Layout.fillWidth: true
        //     height: Units.pt(16)
        //     to: 100
        //     value: {
        //         if (!connlossSubscriber.message || !connlossSubscriber.message.timer_percentage) return 0
        //         return (connlossSubscriber.message.timer_percentage * 100).toFixed(2)
        //     }
        //     backgroundColor: {
        //         if (!connlossSubscriber.message||connlossSubscriber.message.state > 3) return Style.colors.status.unknown
        //         return Style.battery.background
        //     }
        //     foregroundColor: Style.battery.foregroundColor
        //     text: {
        //         if (!connlossSubscriber.message) return "Unknown"
        //         else if (connlossSubscriber.message.state > 3) return "Disabled"
        //         else if (connlossSubscriber.message.state === 1) return "Good Connection"
        //         else if (connlossSubscriber.message.state === 2) return "Timer: " + value +" %"
        //         else if (connlossSubscriber.message.state === 3) return "Returning!"
        //         else if (connlossSubscriber.message.state === 0) return "No Msg received!"
        //         return "Unknown"
        //     }
        // }
    }
}
