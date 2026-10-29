import QtQuick 2.3
import QtQuick.Layouts 1.3
import QtQuick.Controls 2.1
import Hector.InternalControls 1.0
import Hector.MultiRobot 1.0

Item {
    id: root

    property var configuration
    property var style

    signal configurationUpdated

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        TabBar {
            id: bar
            Layout.fillWidth: true
            currentIndex: 1
            spacing: 0
            z: 1

            StyledTabButton {
                style: root.style
                text: "Visualizations"
            }
            StyledTabButton {
                style: root.style
                text: "Behaviors"
            }
            StyledTabButton {
                style: root.style
                text: "Settings"
            }
        }
        StackLayout {
            Layout.fillHeight: true
            Layout.fillWidth: true
            currentIndex: bar.currentIndex

            VisualizationsTab {
                Layout.fillHeight: true
                Layout.fillWidth: true
                robot: RobotManager.activeRobot
                style: root.style
            }
            RobotActionTab {
                Layout.fillHeight: true
                Layout.fillWidth: true
                actionStructure: root.configuration && root.configuration.actionStructure && root.configuration.actionStructure[RobotManager.activeRobot.robot_id] || []
                actions: root.configuration && root.configuration.actions && root.configuration.actions[RobotManager.activeRobot.robot_id] || []
                style: root.style

                onActionStructureUpdated: {
                    if (!root.configuration)
                        root.configuration = {};
                    if (!root.configuration.actionStructure)
                        root.configuration.actionStructure = {};
                    root.configuration.actionStructure[RobotManager.activeRobot.robot_id] = actionStructure;
                    root.configurationUpdated();
                }
                onActionsUpdated: {
                    if (!root.configuration)
                        root.configuration = {};
                    if (!root.configuration.actions)
                        root.configuration.actions = {};
                    root.configuration.actions[RobotManager.activeRobot.robot_id] = actions;
                    root.configurationUpdated();
                }
            }
            SettingsTab {
                Layout.fillHeight: true
                Layout.fillWidth: true
                parameters: root.configuration && root.configuration.params && root.configuration.params[RobotManager.activeRobot.robot_id] || []
                style: root.style

                onParametersUpdated: {
                    if (!root.configuration)
                        root.configuration = {};
                    if (!root.configuration.params)
                        root.configuration.params = {};
                    root.configuration.params[RobotManager.activeRobot.robot_id] = parameters;
                    root.configurationUpdated();
                }
            }
        }
    }
}
