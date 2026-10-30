import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import Hector.Actions
import Hector.Controls
import Hector.Style
import Hector.Utils

Rectangle {
    id: root

    property var execution
    property alias iconColor: actionIcon.backgroundColor

    color: Style.background.content
    implicitHeight: Units.pt(48)
    implicitWidth: actionIcon.implicitWidth * 1.5 + actionText.implicitWidth

    Behavior on color  {
        ColorAnimation {
            duration: 400
        }
    }
    // Finished states are only shown once the execution is no longer active, otherwise the status
    // would claim the action finished while the progress bar and cancel button are still shown.
    states: [
        State {
            name: "success"
            when: !execution.active && execution.state === RobotActionExecution.ExecutionState.Succeeded

            PropertyChanges {
                color: Qt.lighter(Style.colors.status.success, 1.2)
                target: root
            }
            PropertyChanges {
                backgroundColor: Style.colors.status.success
                target: actionIcon
                text: Style.icons.check
            }
        },
        State {
            name: "failed"
            when: !execution.active && execution.state === RobotActionExecution.ExecutionState.Failed

            PropertyChanges {
                color: Qt.lighter(Style.colors.status.error, 1.2)
                target: root
            }
            PropertyChanges {
                backgroundColor: Style.colors.status.error
                target: actionIcon
                text: Style.icons.exclamation
            }
        },
        State {
            name: "canceled"
            when: !execution.active && execution.state === RobotActionExecution.ExecutionState.Canceled

            PropertyChanges {
                color: Qt.lighter(Style.colors.status.warn, 1.2)
                target: root
            }
            PropertyChanges {
                backgroundColor: Style.colors.status.warn
                target: actionIcon
                text: Style.icons.canceled
            }
        },
        State {
            name: "partialFailure"
            when: !execution.active && execution.state === RobotActionExecution.ExecutionState.PartialFailure

            PropertyChanges {
                color: Qt.lighter(Style.colors.status.warn, 1.2)
                target: root
            }
            PropertyChanges {
                backgroundColor: Style.colors.status.warn
                target: actionIcon
                text: Style.icons.exclamation
            }
        },
        State {
            name: "timeout"
            when: !execution.active && execution.state === RobotActionExecution.ExecutionState.Timeout

            PropertyChanges {
                color: Qt.lighter(Style.colors.status.error, 1.2)
                target: root
            }
            PropertyChanges {
                backgroundColor: Style.colors.status.error
                target: actionIcon
                text: Style.icons.clockAlert
            }
        }
    ]

    Progress {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        backgroundColor: "transparent"
        foregroundColor: Style.teleoperation.primary.color
        height: Units.pt(2)
        indefiniteColor: Qt.lighter(Style.teleoperation.primary.color, 1.5)
        value: root.execution.progress
        visible: root.execution.active
    }
    QtObject {
        id: d

        property real scale: Math.max(0.1, root.height / Units.pt(48))
    }
    Icon {
        id: actionIcon
        anchors.left: parent.left
        anchors.leftMargin: Units.pt(8) * d.scale
        anchors.verticalCenter: parent.verticalCenter
        backgroundColor: Style.teleoperation.primary.color
        color: Style.getTextColor(backgroundColor)
        font.family: Style.iconFontFamily
        height: Units.pt(32) * d.scale
        padding: Units.pt(6) * d.scale
        text: execution.action.icon || Style.icons.robotAction
        width: height

        Behavior on backgroundColor  {
            ColorAnimation {
                duration: 400
            }
        }
    }
    Rectangle {
        id: actionText
        anchors.left: actionIcon.right
        anchors.leftMargin: Units.pt(8) * d.scale
        anchors.right: parent.right
        anchors.rightMargin: Units.pt(12) * d.scale
        anchors.verticalCenter: parent.verticalCenter
        color: "transparent"
        implicitHeight: actionStatusLayout.implicitHeight
        implicitWidth: actionStatusLayout.implicitWidth

        ColumnLayout {
            id: actionStatusLayout
            anchors.fill: parent
            spacing: 0

            Text {
                id: mainActionText
                Layout.fillWidth: true
                color: Style.getTextColor(root.color)
                elide: Text.ElideRight
                font.pointSize: Style.fonts.header.pointSize * d.scale
                font.weight: Style.fonts.header.weight
                text: execution.action.name
            }
            Text {
                id: subActionText
                Layout.fillWidth: true
                color: Style.getTextColor(root.color)
                elide: Text.ElideRight
                font.pointSize: Style.fonts.small.pointSize * d.scale
                font.weight: Style.fonts.small.weight
                text: execution.statusText
                visible: !!execution.statusText
            }
        }
        ToolTip {
            delay: 500
            text: mainActionText.text
            visible: mouseArea.containsMouse && mainActionText.truncated
        }
    }
}
