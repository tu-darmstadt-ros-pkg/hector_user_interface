import QtQuick 2.8
import QtQuick.Controls 2.2
import QtQuick.Layouts 1.1
import Ros2 1.0
import Hector.Actions 1.0
import Hector.Controls 1.0
import Hector.Icons 1.0
import Hector.InternalControls 1.0
import Hector.MultiRobot 1.0
import Hector.Style 1.0
import Hector.Utils 1.0
import "robots"
import "sensors"
import "status"
import "dash"
import "notes"
import "operator"
import "visualizations"

Item {
    id: appWindow

    property Robot activeRobot: RobotManager.activeRobot
    property var style: Style.activeStyle

    function updateForActiveRobot() {
        if (!activeRobot)
            return;
        const waypointTool = dTool.waypointTool && dTool.waypointTool.tool;
        if (waypointTool) {
            waypointTool.clearWaypoints();
            waypointTool.robotDescriptionTopic = activeRobot.namespace + "/robot_description";
            waypointTool.jointStateTopic = activeRobot.namespace + "/joint_states";
        }
        updateStyle();
        OcsManager.setActiveRobot(activeRobot);
    }
    function updateStyle() {
        let style = Style.activeStyle;
        if (activeRobot.operationMode == Robot.OperationMode.Safe)
            style = Style.safe;
        else if (activeRobot.operationMode == Robot.OperationMode.Teleoperation)
            style = Style.teleoperation;
        else if (activeRobot.operationMode == Robot.OperationMode.Manipulation)
            style = Style.manipulation;
        Style.setActiveStyle(style);
    }

    anchors.fill: parent

    Component.onCompleted: updateForActiveRobot()

    VisualizationDisplayManager {
    }
    MultiRobotModelDimmer {
    }

    // Declared first so the world-anchored note icons stay below all HUD controls.
    NoteMarkers {
        id: noteMarkers
        anchors.fill: parent
    }

    // Tool controls
    QtObject {
        id: dTool

        property var current: (rviz && rviz.toolManager && rviz.toolManager.currentTool && rviz.toolManager.currentTool) || {
            "classId": ''
        }
        // Reads tools so the lookup re-runs when a config reload recreates every QmlTool wrapper.
        property var waypointTool: {
            if (!rviz || !rviz.toolManager)
                return null;
            rviz.toolManager.tools;
            return rviz.toolManager.getTool("hector_user_interface/WaypointTool");
        }
    }
    Connections {
        function onActiveRobotChanged() {
            updateForActiveRobot();
        }

        target: RobotManager
    }
    Connections {
        function onOperationModeChanged() {
            updateStyle();
        }

        target: activeRobot
    }

    // Time
    Rectangle {
        id: timeRectangle
        color: Style.background.container
        height: Units.pt(24)
        width: Units.pt(48)
        x: 0
        y: Units.pt(24)
        z: 10

        AutoSizeText {
            id: clockText
            function getTime() {
                var date = new Date();
                var hours = date.getHours();
                var minutes = date.getMinutes();
                return hours.toString().padStart(2, "0") + ":" + minutes.toString().padStart(2, "0");
            }

            color: Style.getTextColor(timeRectangle.color)
            text: getTime()

            Timer {
                interval: 10000
                repeat: true
                running: true

                onTriggered: clockText.text = clockText.getTime()
            }
        }
    }
    RobotRecorderStatus {
        id: recorderStatus
        height: timeRectangle.height
        width: timeRectangle.width
        x: timeRectangle.x
        y: timeRectangle.y + timeRectangle.height + Units.pt(4)
        z: timeRectangle.z
    }

    // Multi-robot switcher: collapsible pane of robot tiles, stacked below the
    // clock/recorder status and above the toolbar/dash.
    RobotSwitcher {
        anchors.bottom: toolBar.top
        anchors.bottomMargin: Units.pt(8)
        anchors.left: parent.left
        anchors.top: recorderStatus.bottom
        anchors.topMargin: Units.pt(4)
        visible: RobotManager.robots.length > 1
        z: 10
    }

    // Fullscreen toggle
    OverlayIconButton {
        id: fullscreenButton
        anchors.margins: Units.pt(8)
        anchors.right: parent.right
        anchors.top: parent.top
        font.pointSize: 16
        text: rviz.isFullscreen ? HectorIcons.exitFullscreen : HectorIcons.fullscreen

        onClicked: rviz.isFullscreen = !rviz.isFullscreen
    }
    NoteCounter {
        anchors.right: fullscreenButton.left
        anchors.rightMargin: Units.pt(8)
        anchors.verticalCenter: fullscreenButton.verticalCenter
        tool: noteMarkers.tool

        onOpenRequested: function (note, anchor) {
            noteMarkers.edit(note, anchor);
        }
    }

    // Shows status of currently running robot action(s) and emergency stops
    EStopStatus {
        id: estopStatus
        anchors.bottom: dash.top
        anchors.horizontalCenter: parent.horizontalCenter
        visible: activeEstopCount > 0
        width: Units.pt(200)
    }
    ActiveRobotStatus {
        anchors.bottom: dash.top
        anchors.horizontalCenter: parent.horizontalCenter
        visible: activeRobot.status.status_code !== 0 && activeRobot.status.status_code !== -1
        width: Units.pt(200)
    }
    ActiveRobotActionStatus {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: activeRobot.actionManager.activeExecutions.length > 0 ? 0 : -height - 2
        width: Units.pt(240)

        Behavior on anchors.topMargin  {
            NumberAnimation {
            }
        }
    }
    RvizToolbar {
        id: toolBar
        anchors.bottom: dash.top
        anchors.left: parent.left
        anchors.margins: Units.pt(4)
        buttonRadius: Units.pt(2)
        editable: false
        height: Units.pt(24)
        iconMargin: Units.pt(5)
        selectedColor: appWindow.style.primary.color
        shortcutFont: Qt.font({
                "pointSize": 8
            })
    }
    Image {
        property var logoProperty: rviz.registerBoolProperty("TUDa Branding", false, "Activate to display the TU Darmstadt logo prominently in the UI.")
        property real scale: Math.max(toolBar.width + Units.pt(48), Units.pt(120)) / sourceSize.width

        anchors.bottom: hectorLogo.visible ? hectorLogo.top : toolBar.top
        anchors.bottomMargin: Units.pt(16)
        anchors.left: parent.left
        height: sourceSize.height * scale
        source: "../media/tuda_logo.png"
        visible: logoProperty && logoProperty.value || false
        width: sourceSize.width * scale
    }
    Image {
        id: hectorLogo

        property var logoProperty: rviz.registerBoolProperty("Branding", false, "Activate to display the team hector logo prominently in the UI.")
        property real scale: Math.max(toolBar.width + Units.pt(96), Units.pt(240)) / sourceSize.width

        anchors.bottom: toolBar.bottom
        anchors.left: parent.left
        anchors.leftMargin: Units.pt(8)
        height: sourceSize.height * scale
        smooth: true
        source: "../media/logo.svg"
        visible: logoProperty && logoProperty.value || false
        width: sourceSize.width * scale
    }
    WaypointToolControls {
        id: waypointToolControls
        anchors.bottom: dash.top
        anchors.margins: Units.pt(4)
        anchors.right: parent.right
        style: appWindow.style
        visible: dTool.waypointTool && dTool.waypointTool.tool.waypoints.length > 0
        waypointTool: dTool.waypointTool
    }
    SensorValues {
        anchors.left: timeRectangle.right
        anchors.leftMargin: Units.pt(32)
        anchors.top: parent.top
        anchors.topMargin: Units.pt(4)
    }
    Dash {
        id: dash

        property var dashHeightProperty: rviz.registerFloatProperty("Dash Height", 160)

        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.margins: -2
        anchors.right: parent.right
        configuration: rviz.config
        height: Units.pt(dashHeightProperty.value)
        style: appWindow.style

        onConfigurationUpdated: {
            rviz.config = configuration;
        }
        onHeightChanged: if (Math.abs(Units.toPt(height) - dashHeightProperty.value) > 0.3)
            dashHeightProperty.value = Units.toPt(height)
    }

    // Declared last so its scrim/cards/modal stack above the dash and status widgets.
    OperatorRequests {
        anchors.fill: parent
        bottomInset: dash.height + (waypointToolControls.visible ? waypointToolControls.height + Units.pt(4) : 0) + Units.pt(4)
    }
}
