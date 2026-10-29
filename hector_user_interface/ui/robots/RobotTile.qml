import QtQuick 2.3
import QtQuick.Controls 2.2
import QtQuick.Layouts 1.1
import QtMultimedia 5.15
import Ros2.CameraServer 1.0
import Hector.Actions 1.0
import Hector.Controls 1.0
import Hector.MultiRobot 1.0
import Hector.Style 1.0
import Hector.Utils 1.0
import "../sensors"

// A tile for a single robot: live camera feed on top with buttons to step through the
// robot's cameras, below it the robot name, what the robot is currently doing and one of its
// announced sensor values. Camera and sensor choice are per robot and persist in the rviz config.
// The star in the top right corner toggles the pin.
Rectangle {
    id: root

    //! Whether this tile's robot is the active robot, highlighted by a border.
    readonly property bool active: !!RobotManager.activeRobot && !!root.robot && root.robot.robot_id === RobotManager.activeRobot.robot_id

    // What the tile reports below the name: the robot's action activity while something runs (and
    // for as long as the finished executions are kept around), otherwise the robot status.
    readonly property var activity: d.executionInfo() || d.statusInfo()

    //! This robot's cameras, in server order.
    readonly property var cameras: (CameraServer.cameras || []).filter(camera => camera.server && camera.server.robot === robotId)
    //! Camera shown in the tile: the selected one, the robot's first if the selected one is not (or
    //! no longer) available, null if it has none.
    readonly property var matchedCamera: cameras.find(camera => camera.cameraId === d.selection("robotTileCameras")) || cameras[0] || null
    property bool pinned: false
    property var robot
    readonly property string robotId: robot ? robot.robot_id : ""
    readonly property var selectedSensor: sensors.find(sensor => sensor.id === d.selection("robotTileSensors")) || sensors[0] || null

    //! Sensors announced by this robot and the one shown in the tile (the selected one, else the
    //! first announced).
    readonly property var sensors: robot && robot.sensors ? robot.sensors : []

    signal clicked
    signal pinToggled

    border.color: Style.activeStyle.primary.color
    border.width: active ? Units.pt(2) : 0
    clip: true
    color: Style.background.content
    implicitHeight: Units.pt(120)
    implicitWidth: Units.pt(200)

    // Tile click switches the active robot. Declared first so it sits below the
    // content; clicks on the (non-interactive) camera/name fall through to it,
    // while the buttons and pin overlay above keep their own clicks.
    MouseArea {
        anchors.fill: parent

        onClicked: root.clicked()
    }
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Units.pt(4)
        spacing: Units.pt(2)

        Rectangle {
            Layout.fillHeight: true
            Layout.fillWidth: true
            Layout.minimumWidth: Units.pt(64)
            clip: true
            color: "black"

            VideoOutput {
                id: videoOutput
                anchors.fill: parent
                fillMode: VideoOutput.PreserveAspectCrop
                source: cameraStream
            }
            CameraStream {
                id: cameraStream
                cameraId: root.matchedCamera ? root.matchedCamera.cameraId : ""
                enabled: root.matchedCamera !== null
                preferredSize: Qt.size(videoOutput.width, videoOutput.height)
                robot: root.robotId
            }

            // Placeholder when no camera is (yet) available for this robot.
            Text {
                anchors.centerIn: parent
                color: Qt.rgba(1, 1, 1, 0.35)
                font.family: Style.iconFontFamily
                font.pixelSize: Math.min(parent.width, parent.height) * 0.4
                text: Style.icons.camera
                visible: !root.matchedCamera
            }

            // Hover detection for the camera switch overlay. Accepts no buttons so clicks still
            // reach the tile's MouseArea and switch the active robot.
            MouseArea {
                id: cameraHoverArea
                acceptedButtons: Qt.NoButton
                anchors.fill: parent
                hoverEnabled: true
            }

            // Camera switching, only meaningful if the robot offers more than one camera.
            Item {
                anchors.fill: parent
                // Disabled while hidden so a click on a faded out button doesn't switch cameras.
                enabled: cameraHoverArea.containsMouse || previousCameraButton.hovered || nextCameraButton.hovered
                opacity: enabled ? 1 : 0
                visible: root.cameras.length > 1

                Behavior on opacity  {
                    NumberAnimation {
                        duration: 150
                    }
                }

                OverlayIconButton {
                    id: previousCameraButton
                    anchors.left: parent.left
                    anchors.margins: Units.pt(2)
                    anchors.verticalCenter: parent.verticalCenter
                    font.pixelSize: Units.pt(16)
                    implicitWidth: Units.pt(20)
                    text: Style.icons.previous

                    onClicked: d.selectRelativeCamera(-1)
                }
                OverlayIconButton {
                    id: nextCameraButton
                    anchors.margins: Units.pt(2)
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    font.pixelSize: Units.pt(16)
                    implicitWidth: Units.pt(20)
                    text: Style.icons.next

                    onClicked: d.selectRelativeCamera(1)
                }

                // Name of the shown camera, so switching is not a blind guess.
                Text {
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: Units.pt(2)
                    anchors.horizontalCenter: parent.horizontalCenter
                    color: "white"
                    elide: Text.ElideRight
                    font: Style.fonts.tiny
                    horizontalAlignment: Text.AlignHCenter
                    style: Text.Outline
                    styleColor: Qt.rgba(0, 0, 0, 0.6)
                    text: root.matchedCamera ? root.matchedCamera.name || root.matchedCamera.cameraId : ""
                    width: parent.width - 2 * (previousCameraButton.width + Units.pt(6))
                }
            }
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: Units.pt(4)

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                Text {
                    Layout.fillWidth: true
                    color: Style.getTextColor(root.color)
                    elide: Text.ElideRight
                    font: Style.fonts.subHeader
                    text: root.robot ? root.robot.name : ""
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Units.pt(4)

                    Rectangle {
                        Layout.alignment: Qt.AlignVCenter
                        color: root.activity.color
                        height: width
                        radius: width / 2
                        width: Units.pt(8)
                    }
                    Text {
                        Layout.fillWidth: true
                        color: Style.getTextColor(root.color)
                        elide: Text.ElideRight
                        font: Style.fonts.small
                        text: root.activity.label
                    }
                }
            }

            // Sensor value; click to show another of the robot's announced sensors.
            Item {
                id: sensorDisplay
                Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
                implicitHeight: sensorLayout.implicitHeight
                implicitWidth: sensorLayout.implicitWidth
                visible: root.sensors.length > 0

                RowLayout {
                    id: sensorLayout
                    anchors.fill: parent
                    spacing: Units.pt(2)

                    Text {
                        color: d.sensorColor
                        font.family: Style.iconFontFamily
                        font.pixelSize: Units.pt(14)
                        text: (root.selectedSensor && Style.icons[root.selectedSensor.icon]) || Style.icons.manometer
                    }
                    Text {
                        color: d.sensorColor
                        font: Style.fonts.subHeader
                        text: sensorSource.text
                    }
                    Text {
                        color: d.sensorColor
                        font: Style.fonts.tiny
                        text: root.selectedSensor ? root.selectedSensor.unit : ""
                        visible: text.length > 0
                    }
                }
                SensorValueSource {
                    id: sensorSource
                    sensor: root.selectedSensor
                }
                SimpleToolTip {
                    text: root.selectedSensor ? root.selectedSensor.name + "\n" + root.selectedSensor.topic + "\nClick to select another sensor" : ""
                }
                MouseArea {
                    anchors.fill: parent

                    onClicked: sensorMenu.open()
                }
                Menu {
                    id: sensorMenu
                    y: sensorDisplay.height

                    Repeater {
                        model: root.sensors

                        MenuItem {
                            checkable: true
                            checked: root.selectedSensor && root.selectedSensor.id === modelData.id
                            text: modelData.unit ? modelData.name + " (" + modelData.unit + ")" : modelData.name

                            onTriggered: d.setSelection("robotTileSensors", modelData.id)
                        }
                    }
                }
            }
        }
    }

    // Pin toggle. Declared last so it stays above the tile's MouseArea.
    OverlayIconButton {
        anchors.margins: Units.pt(2)
        anchors.right: parent.right
        anchors.top: parent.top
        font.pixelSize: Units.pt(16)
        implicitWidth: Units.pt(20)
        palette.buttonText: root.pinned ? Style.activeStyle.primary.color : "white"
        text: Style.icons.star

        onClicked: root.pinToggled()
    }
    QtObject {
        id: d

        readonly property color sensorColor: {
            if (sensorSource.dangerous)
                return Style.colors.status.error;
            if (sensorSource.warn)
                return Style.colors.status.warn;
            return Style.getTextColor(root.color);
        }

        //! { color, label } describing the robot's action executions, null if none are running or
        //! finished recently. Finished executions are kept by the action manager for a few seconds,
        //! which is what shows their result.
        function executionInfo() {
            let executions = root.robot && root.robot.actionManager ? root.robot.actionManager.activeExecutions : [];
            if (!executions || executions.length === 0)
                return null;
            let name = executions.length === 1 ? d.executionName(executions[0]) : executions.length + " actions";
            let result = d.resultInfo(ExecutionStates.summaryState(executions));
            return ({
                    "color": result.color,
                    "label": result.label ? name + ": " + result.label : name
                });
        }

        //! The execution's action name. While a composite runs, followed by its current subaction if
        //! sequential, or by the number of still running subactions if parallel.
        function executionName(execution) {
            let action = execution.action;
            let subexecutions = execution.subexecutions;
            if (!execution.active || action.type !== "composite" || subexecutions.length === 0)
                return action.name;
            if (action.parallel)
                return action.name + ": " + subexecutions.length + (subexecutions.length === 1 ? " subaction" : " subactions") + " running";
            return action.name + ": " + subexecutions[0].action.name;
        }

        //! Color and, for finished executions, the result label of an execution state.
        function resultInfo(state) {
            switch (state) {
            case RobotActionExecution.ExecutionState.Succeeded:
                return {
                    "color": Style.colors.status.success,
                    "label": "Succeeded"
                };
            case RobotActionExecution.ExecutionState.Failed:
                return {
                    "color": Style.colors.status.error,
                    "label": "Failed"
                };
            case RobotActionExecution.ExecutionState.Timeout:
                return {
                    "color": Style.colors.status.error,
                    "label": "Timed out"
                };
            case RobotActionExecution.ExecutionState.PartialFailure:
                return {
                    "color": Style.colors.status.warn,
                    "label": "Partially failed"
                };
            case RobotActionExecution.ExecutionState.Canceled:
                return {
                    "color": Style.colors.status.warn,
                    "label": "Canceled"
                };
            case RobotActionExecution.ExecutionState.Canceling:
                return {
                    "color": Style.colors.status.warn,
                    "label": ""
                };
            default:
                return {
                    "color": Style.colors.status.info,
                    "label": ""
                };
            }
        }

        //! Selects the camera offset positions after the current one, wrapping around.
        function selectRelativeCamera(offset) {
            let cameras = root.cameras;
            if (cameras.length === 0)
                return;
            let current = Math.max(0, cameras.indexOf(root.matchedCamera));
            let next = (current + offset + cameras.length) % cameras.length;
            d.setSelection("robotTileCameras", cameras[next].cameraId);
        }

        //! This robot's selection stored under the given rviz config key, "" if it has none.
        function selection(key) {
            let selections = rviz.config[key];
            return selections && selections[root.robotId] || "";
        }
        function setSelection(key, id) {
            if (!root.robotId)
                return;
            let config = rviz.config;
            let selections = config[key] || ({});
            selections[root.robotId] = id;
            config[key] = selections;
            rviz.config = config;
        }

        //! { color, label } for the robot's status_code.
        //! Codes are the hector_multi_robot_msgs/RobotStatus STATUS_* constants (OK, INFO, WARNING, ERROR, ESTOP).
        function statusInfo() {
            switch (root.robot && root.robot.status ? root.robot.status.status_code : -1) {
            case 0:
                return {
                    "color": Style.colors.status.ok,
                    "label": "Ready"
                };
            case 40:
                return {
                    "color": Style.colors.status.info,
                    "label": "Info"
                };
            case 128:
                return {
                    "color": Style.colors.status.warn,
                    "label": "Warn"
                };
            case 200:
                return {
                    "color": Style.colors.status.error,
                    "label": "Error"
                };
            case 220:
                return {
                    "color": Style.colors.status.error,
                    "label": "E-Stop"
                };
            default:
                return {
                    "color": Style.colors.status.unknown,
                    "label": "Unknown"
                };
            }
        }
    }
}
