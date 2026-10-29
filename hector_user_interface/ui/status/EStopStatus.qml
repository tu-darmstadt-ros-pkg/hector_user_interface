import QtQuick 2.3
import QtQuick.Controls 2.2
import QtQuick.Layouts 1.1
import Hector.Controls 1.0
import Hector.Style 1.0
import Hector.Utils 1.0
import Ros2 1.0
import Hector.MultiRobot 1.0

Item {
    id: root

    property int activeEstopCount: {
        if (!estopStates)
            return 0;
        var count = 0;
        for (let estop of estopStates) {
            if (estop.value)
                ++count;
        }
        return count;
    }
    property var estopStates: {
        if (!estopSubscriber.message)
            return [];
        var result = [];
        for (var i = 0; i < estopSubscriber.message.names.length; ++i) {
            result.push({
                    "name": estopSubscriber.message.names.at(i),
                    "value": estopSubscriber.message.values.at(i)
                });
        }
        return result;
    }

    implicitHeight: estopDetails.implicitHeight + estopStatus.implicitHeight
    implicitWidth: Math.max(estopDetails.implicitWidth, estopStatus.implicitWidth)

    onVisibleChanged: {
        if (!visible)
            estopDetails.showDetails = false;
    }

    Subscription {
        id: estopSubscriber
        topic: RobotManager.activeRobot.namespace + "/e_stop_manager/e_stop_list"
        qos: Ros2.QoS().transient_local().reliable().keep_last(1)
    }
    Rectangle {
        id: estopStatus
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        color: Style.emergencyStop.checkedColor
        implicitHeight: eStopLayout.implicitHeight
        implicitWidth: eStopLayout.implicitWidth

        RowLayout {
            id: eStopLayout
            anchors.fill: parent

            Icon {
                Layout.margins: Units.pt(8)
                Layout.preferredHeight: Units.pt(36)
                Layout.preferredWidth: Units.pt(36)
                backgroundColor: Style.getTextColor(Style.emergencyStop.checkedColor)
                color: Style.emergencyStop.checkedColor
                text: Style.icons.stop
            }
            ColumnLayout {
                Layout.alignment: Qt.AlignVCenter
                Layout.fillWidth: true
                Layout.rightMargin: Units.pt(12)

                Text {
                    Layout.fillWidth: true
                    color: Style.getTextColor(Style.emergencyStop.checkedColor)
                    font: Style.fonts.header
                    text: "Stopped!"
                }
                Text {
                    Layout.fillWidth: true
                    color: Style.getTextColor(Style.emergencyStop.checkedColor)
                    font: Style.fonts.subHeader
                    text: activeEstopCount + " E-Stop" + (activeEstopCount == 1 ? "" : "s") + " active"
                }
            }
        }
        Text {
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Units.pt(4)
            anchors.right: parent.right
            anchors.rightMargin: Units.pt(8)
            color: Style.getTextColor(Style.emergencyStop.checkedColor)
            font: Style.fonts.tiny
            text: estopDetails.showDetails ? "Hide" : "Show Details"
        }
        MouseArea {
            anchors.fill: parent

            onClicked: estopDetails.showDetails = !estopDetails.showDetails
        }
    }
    Rectangle {
        id: estopDetails

        property var showDetails: false

        anchors.bottom: estopStatus.top
        anchors.left: parent.left
        anchors.right: parent.right
        color: Style.background.content
        height: showDetails ? Math.min(root.estopStates.length * Units.pt(24) + Units.pt(16), Units.pt(320)) : 0

        Behavior on height  {
            NumberAnimation {
            }
        }

        ListView {
            id: estopListView
            anchors.fill: parent
            anchors.leftMargin: Units.pt(8)
            anchors.rightMargin: Units.pt(8)
            bottomMargin: Units.pt(8)
            clip: true
            model: root.estopStates
            topMargin: Units.pt(8)

            delegate: EStopStatusItem {
                height: Units.pt(24)
                name: modelData.name
                value: modelData.value
                width: parent.width
            }
        }
    }
}
