import QtQuick 2.3
import QtQuick.Controls.Basic 2.2
import QtQuick.Layouts 1.1
import Hector.Actions 1.0
import Hector.Controls 1.0
import Hector.InternalControls 1.0
import Hector.MultiRobot 1.0
import Hector.Style 1.0
import Hector.Utils 1.0

Rectangle {
    id: root
    implicitHeight: robotActionStatus.implicitHeight + robotActionDetails.implicitHeight
    implicitWidth: robotActionStatus.implicitWidth

    QtObject {
        id: d

        property var actionManager: RobotManager.activeRobot.actionManager
        property var activeExecutions: d.actionManager.activeExecutions || []
        property bool canceling: {
            if (!d.activeExecutions)
                return false;
            return d.activeExecutions.every(x => !x.active || x.state == RobotActionExecution.ExecutionState.Canceling);
        }
        property int countDone: {
            if (!activeExecutions)
                return 0;
            var count = 0;
            for (let execution of d.activeExecutions) {
                if (execution.active === true)
                    continue;
                count++;
            }
            return count;
        }
        property int countExecutions: {
            if (!d.activeExecutions)
                return 0;
            return d.activeExecutions.length;
        }
        property RobotActionExecution summaryExecution: RobotActionExecution {
            active: d.countExecutions !== d.countDone
            progress: {
                if (!d.activeExecutions)
                    return false;
                if (d.countExecutions === 0)
                    return 0;
                if (d.countExecutions === 1)
                    return d.activeExecutions[0].progress;
                // Compute progress bounds of all active executions
                let minProgress = d.countDone;
                let maxProgress = minProgress;
                for (let execution of d.activeExecutions) {
                    if (!execution.active)
                        // Already counted by done
                        continue;
                    if (!execution.progress) {
                        maxProgress += 1;
                        continue;
                    }
                    if (execution.progress.length == 2) {
                        minProgress += execution.progress[0];
                        maxProgress += execution.progress[1];
                        continue;
                    }
                    minProgress += execution.progress;
                    maxProgress += execution.progress;
                }
                return [minProgress / d.countExecutions, maxProgress / d.countExecutions];
            }
            state: {
                // Keep the result state of the batch once its executions were removed for the slide out animation
                if (d.activeExecutions.length === 0)
                    return d.actionManager.batchResultState;
                return ExecutionStates.summaryState(d.activeExecutions);
            }
            statusText: {
                if (d.countExecutions === 0)
                    return "";
                if (d.countExecutions > 1)
                    return d.countDone + " out of " + d.countExecutions + " completed";
                let execution = d.activeExecutions[0];
                return execution.statusText;
            }

            action: RobotAction {
                icon: {
                    if (d.activeExecutions && d.activeExecutions.length == 1 && d.activeExecutions[0].action.icon)
                        return d.activeExecutions[0].action.icon;
                    return Style.icons.robotAction;
                }
                name: {
                    if (d.countExecutions > 1)
                        return d.countExecutions + " actions running";
                    return d.countExecutions === 1 ? d.activeExecutions[0].action.name : "";
                }
                type: "composite"
            }
        }

        onCountExecutionsChanged: {
            if (countExecutions > 1)
                return;
            robotActionDetails.showDetails = false;
        }
    }
    Rectangle {
        id: robotActionStatus
        clip: true
        implicitHeight: summaryLayout.implicitHeight
        implicitWidth: summaryLayout.implicitWidth
        width: parent.width

        RowLayout {
            id: summaryLayout
            width: parent.width

            RobotActionExecutionStatus {
                id: actionSummary
                Layout.fillHeight: true
                Layout.fillWidth: true
                execution: d.activeExecutions.length == 1 ? d.activeExecutions[0] : d.summaryExecution
                width: parent.width

                MouseArea {
                    id: mouseArea
                    anchors.fill: parent
                    hoverEnabled: true

                    onClicked: {
                        if (d.activeExecutions.length <= 1)
                            return;
                        robotActionDetails.showDetails = !robotActionDetails.showDetails;
                    }
                }
            }
            // Cancel all
            StyledButton {
                id: cancelAllButton
                Layout.fillHeight: true
                style: Style.teleoperation
                visible: d.summaryExecution.active

                onClicked: {
                    for (let execution of d.activeExecutions) {
                        d.actionManager.cancel(execution.action);
                    }
                }
                onPressAndHold: {
                    for (let execution of d.activeExecutions) {
                        d.actionManager.cancel(execution.action, true);
                    }
                }

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 0

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        color: Style.getTextColor(cancelAllButton.style.primary.color)
                        text: Style.icons.cancel
                        visible: !d.canceling

                        font {
                            family: Style.iconFontFamily
                            pointSize: 24
                        }
                    }
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        color: Style.getTextColor(cancelAllButton.style.primary.color)
                        font.pointSize: 9
                        font.weight: Font.Bold
                        text: d.countExecutions > 1 ? "Cancel All" : "Cancel"
                        visible: !d.canceling
                    }
                }
                Text {
                    anchors.fill: parent
                    color: Style.getTextColor(cancelAllButton.style.primary.color)
                    font.pointSize: 11
                    font.weight: Font.Bold
                    horizontalAlignment: Text.AlignHCenter
                    text: "Hold to force cancel"
                    verticalAlignment: Text.AlignVCenter
                    visible: d.canceling
                    wrapMode: Text.WordWrap
                }
            }
        }
        Text {
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Units.pt(2)
            anchors.right: parent.right
            anchors.rightMargin: Units.pt(8) + cancelAllButton.width
            color: Style.getTextColor(Style.background.content)
            font: Style.fonts.tiny
            text: robotActionDetails.showDetails ? "Hide" : "Show Details"
            visible: d.activeExecutions.length > 1
        }
    }
    Rectangle {
        id: robotActionDetails

        property bool showDetails: false

        anchors.top: robotActionStatus.bottom
        color: Style.background.content
        height: showDetails ? Math.min(d.activeExecutions.length * Units.pt(36), Units.pt(320)) : 0
        width: parent.width

        Behavior on height  {
            NumberAnimation {
            }
        }

        ListView {
            id: robotActionListView
            anchors.fill: parent
            clip: true
            model: d.activeExecutions

            delegate: RobotActionExecutionStatus {
                execution: modelData
                height: Units.pt(36)
                width: root.width
            }
        }
    }
}
