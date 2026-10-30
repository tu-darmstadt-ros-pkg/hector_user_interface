import QtQuick 2.3
import QtQuick.Controls.Basic 2.1
import QtQuick.Templates as T
import Ros2 1.0
import Hector.Controls 1.0
import Hector.InternalControls 1.0
import Hector.Utils 1.0
import Hector.Style 1.0
import Hector.MultiRobot 1.0

Button {
    id: robotRecorderStatus

    property double lastMsgMs: 0
    property int recorderState: -1  // -1=no node, 0=idle, 1=recording, 2=paused
    property color stateColor: recorderState === 1 ? "#15b315" : recorderState === 2 ? "#FF9800" : Style.colors.status.unknown
    property int statusSeq: 0
    property int timeoutMs: 1500
    property int updatePeriodMs: 1000

    ToolTip.delay: 400
    ToolTip.text: recorderState === 1 ? "Recording" : recorderState === 2 ? "Recording paused" : recorderState === 0 ? "Not recording" : "Onboard logging node not detected"
    ToolTip.visible: hovered
    checkable: false
    enabled: !recorderPopup.opened
    font.pointSize: 15
    text: "REC"

    background: Rectangle {
        color: Style.handleMouseStates(robotRecorderStatus, stateColor)
    }
    contentItem: Row {
        LayoutMirroring.childrenInherit: false
        LayoutMirroring.enabled: false
        anchors.centerIn: parent
        layoutDirection: Qt.LeftToRight
        spacing: Units.pt(4)

        Text {
            anchors.verticalCenter: parent.verticalCenter
            color: "black"
            font.family: Style.iconFontFamily
            font.pixelSize: Math.round(robotRecorderStatus.height * 0.55)
            text: recorderState === 1 ? Style.icons.cancel : recorderState === 2 ? Style.icons.pause : recorderState === 0 ? Style.icons.stop : Style.icons.canceled
            verticalAlignment: Text.AlignVCenter
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            color: "black"
            font: robotRecorderStatus.font
            text: robotRecorderStatus.text
            verticalAlignment: Text.AlignVCenter
        }
    }

    onClicked: recorderPopup.opened ? recorderPopup.close() : recorderPopup.open()

    Subscription {
        id: recorderStatusSubscriber
        topic: RobotManager.activeRobot.namespace + "/onboard_logging_status"

        onNewMessage: function (message) {
            robotRecorderStatus.lastMsgMs = Date.now();
            robotRecorderStatus.statusSeq += 1;
            robotRecorderStatus.recorderState = message.state;
        }
    }
    Timer {
        interval: updatePeriodMs
        repeat: true
        running: true
        triggeredOnStart: true

        onTriggered: {
            if ((Date.now() - robotRecorderStatus.lastMsgMs) > timeoutMs)
                robotRecorderStatus.recorderState = -1;
        }
    }
    RobotRecorderStatusList {
        id: recorderPopup
        focus: true
        height: Math.min(parent.height * 0.35, Units.pt(320))
        parent: T.Overlay.overlay
        statusMsg: recorderStatusSubscriber.message
        statusSeq: robotRecorderStatus.statusSeq
        title: "Onboard Logging"
        updatePeriodMs: robotRecorderStatus.updatePeriodMs
        width: Math.min(parent.width * 0.6, Units.pt(780))
        x: (parent.width - width) / 2
        y: 5
    }
}
