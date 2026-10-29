import QtQuick 2.3
import QtQuick.Layouts 1.1
import Ros2 1.0
import Hector.Controls 1.0
import Hector.Utils 1.0
import Hector.InternalControls 1.0
import Hector.MultiRobot 1.0
import Hector.Style 1.0
import "dash"

Rectangle {
    id: root

    property var configuration
    property var style

    signal configurationUpdated

    function cameraLayoutsConfig(robot) {
        if (!configuration || !robot)
            return [];
        // Legacy configs stored cameraLayouts as one global array; reset it to the per-robot
        // map, intentionally dropping the old global layouts.
        if (!configuration.cameraLayouts || Array.isArray(configuration.cameraLayouts))
            configuration.cameraLayouts = {};
        if (!configuration.cameraLayouts[robot.robot_id])
            configuration.cameraLayouts[robot.robot_id] = [];
        return configuration.cameraLayouts[robot.robot_id];
    }

    // Camera views and layouts are stored per robot (keyed by robot_id) in the shared
    // rviz config, so switching the active robot swaps to that robot's configured cameras.
    // Getters lazily create an empty slot so edits persist; they return a throwaway empty
    // value when no robot is active so the grids show nothing.
    function cameraViewConfig(robot) {
        if (!configuration || !robot)
            return {
                "cameras": []
            };
        if (!configuration.cameraViews)
            configuration.cameraViews = {};
        if (!configuration.cameraViews[robot.robot_id])
            configuration.cameraViews[robot.robot_id] = {
                "cameras": []
            };
        return configuration.cameraViews[robot.robot_id];
    }
    function storeCameraLayoutsConfig(robot, layouts) {
        if (!configuration || !robot)
            return;
        if (!configuration.cameraLayouts || Array.isArray(configuration.cameraLayouts))
            configuration.cameraLayouts = {};
        configuration.cameraLayouts[robot.robot_id] = layouts;
    }
    function storeCameraViewConfig(robot, cameraView) {
        if (!configuration || !robot)
            return;
        if (!configuration.cameraViews)
            configuration.cameraViews = {};
        configuration.cameraViews[robot.robot_id] = cameraView;
    }

    color: Style.background.container

    Component.onCompleted: {
        if (!rviz)
            console.error("No rviz context property. Can't register properties!");
    }

    border {
        color: style.primary.color
        width: Units.pt(1)
    }

    // Catches all mouse events that weren't handled by dash components to prevent them from going to rviz
    MouseArea {
        acceptedButtons: Qt.AllButtons
        anchors.fill: parent

        onWheel: wheel.accepted = true
    }
    ResizeHandle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: Units.pt(4)
        minimumHeight: Units.pt(200)
        resizeBorder: ResizeHandle.Border.Top
        resizeMode: ResizeHandle.SizeOnly
        target: root
        z: 2
    }
    RowLayout {
        anchors.fill: parent
        anchors.topMargin: Units.pt(1)

        ColumnLayout {
            Layout.fillHeight: true
            Layout.maximumWidth: Units.pt(90)
            Layout.minimumWidth: Units.pt(72)
            Layout.preferredWidth: Units.pt(90)
            spacing: 0

            ViewControllerControl {
                Layout.fillWidth: true
                Layout.margins: Units.pt(2)
                Layout.preferredHeight: Units.pt(64)
                robotFrame: {
                    let robot = RobotManager.activeRobot;
                    if (!robot)
                        return "";
                    // In the robot namespace rviz reads the robot's unprefixed tf
                    if (robot.namespace == rviz.namespace)
                        return robot.baseFrame.substring(robot.tfPrefix.length);
                    return robot.baseFrame;
                }
                style: root.style
            }
            RobotStatus {
                id: robotStatus
                Layout.fillWidth: true
                Layout.margins: Units.pt(4)
            }

            // Spacer
            Item {
                Layout.fillHeight: true
            }

            // ============ E-STOP ============
            StyledButton {
                id: control

                property bool active: false
                property bool sending: false
                property var serviceClient: Ros2.createServiceClient(RobotManager.activeRobot.namespace + "/e_stop_manager/set_e_stop", "e_stop_manager_msgs/srv/SetEStop")

                Layout.fillWidth: true
                Layout.margins: Units.pt(4)
                Layout.preferredHeight: Units.pt(24)
                buttonStyle: Style.emergencyStop
                checkable: true
                font.pointSize: 14
                text: sending ? "Sending..." : checked ? "Stopped" : "E-Stop"

                onClicked: {
                    if (sending) {
                        checked = active; // Ignore clicks while a request is in flight
                        return;
                    }
                    var target = !active;
                    checked = active; // Keep the confirmed state until the service responds
                    sending = true;
                    serviceClient.sendRequestAsync({
                            "name": "ui_e_stop",
                            "value": target
                        }, function (response) {
                            sending = false;
                            if (!!response && response.result == 0) {
                                active = target;
                                checked = target;
                                return;
                            }
                            checked = active; // Revert to the confirmed state
                            Ros2.error("Failed to set e-stop! Result: " + JSON.stringify(response && response.result));
                        });
                }
            }
        }
        ColumnLayout {
            Layout.fillHeight: true
            Layout.maximumWidth: Units.pt(124)
            Layout.minimumWidth: Units.pt(124)
            Layout.preferredWidth: Units.pt(124)
            spacing: 0

            RobotOrientationView {
                Layout.fillWidth: true
                Layout.margins: Units.pt(2)
                Layout.preferredHeight: Units.pt(64)
                baseFrame: RobotManager.activeRobot ? RobotManager.activeRobot.baseFrame : ""
                flipperFrames: {
                    if (!RobotManager.activeRobot || !RobotManager.activeRobot.configuration || !RobotManager.activeRobot.configuration["flipper_links"])
                        return [];
                    //! 4 frames = [FL,FR,BR,BL] clockwise from above; 2 frames = [front,back] (linked pairs).
                    let raw = RobotManager.activeRobot.configuration["flipper_links"];
                    let tfPrefix = RobotManager.activeRobot.tfPrefix;
                    try {
                        return JSON.parse(raw).map(function (frame) {
                                return tfPrefix + frame;
                            });
                    } catch (e) {
                        Ros2.warn("Could not parse flipper_links '" + raw + "' as a JSON array: " + e);
                        return [];
                    }
                }
                imuTopic: RobotManager.activeRobot ? RobotManager.activeRobot.namespace + "/imu" : ""
                reverse: RobotManager.activeRobot ? RobotManager.activeRobot.teleopDriveReversed : false
                type: RobotType.fromString(RobotManager.activeRobot ? RobotManager.activeRobot.type : "")
                visible: type === RobotType.Tracked || type === RobotType.Wheeled
            }
            JoyMode {
                Layout.fillWidth: true
                Layout.margins: Units.pt(2)
            }
            CameraLayouts {
                Layout.fillHeight: true
                Layout.fillWidth: true
                configuration: root.cameraLayoutsConfig(RobotManager.activeRobot)

                onConfigurationUpdated: function (layouts) {
                    root.storeCameraLayoutsConfig(RobotManager.activeRobot, layouts);
                    // Re-drive the configuration binding so the new array identity reaches the
                    // list; the child no longer refreshes itself to keep its binding intact.
                    root.configurationChanged();
                    root.configurationUpdated();
                }
            }
        }
        MultiCameraGridView {
            id: leftCameraView
            Layout.fillHeight: true
            Layout.fillWidth: true
            Layout.minimumWidth: Units.pt(120)
            Layout.preferredWidth: 1
            configuration: root.cameraViewConfig(RobotManager.activeRobot)

            onConfigurationUpdated: {
                root.storeCameraViewConfig(RobotManager.activeRobot, configuration);
                root.configurationChanged();
                root.configurationUpdated();
            }
        }
        MultiCameraGridView {
            id: rightCameraView
            Layout.fillHeight: true
            Layout.fillWidth: true
            Layout.minimumWidth: Units.pt(120)
            Layout.preferredWidth: 1
            configuration: root.cameraViewConfig(RobotManager.activeRobot)

            onConfigurationUpdated: {
                root.storeCameraViewConfig(RobotManager.activeRobot, configuration);
                root.configurationChanged();
                root.configurationUpdated();
            }
        }
        RobotControlTabView {
            Layout.fillHeight: true
            Layout.fillWidth: true
            Layout.minimumWidth: Units.pt(80)
            Layout.preferredWidth: 1
            configuration: root.configuration.robotActions
            style: root.style

            onConfigurationUpdated: {
                root.configuration.robotActions = configuration;
                root.configurationUpdated();
            }
        }
    }
}
