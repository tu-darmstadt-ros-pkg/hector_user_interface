import QtQuick 2.3
import QtQuick.Controls.Basic 2.2
import QtQuick.Layouts 1.1
import Hector.Controls 1.0
import Hector.MultiRobot 1.0
import Hector.Style 1.0
import Hector.Utils 1.0
import Ros2 1.0

Item {
    id: root
    implicitHeight: backgroundRectangle.implicitHeight
    implicitWidth: backgroundRectangle.implicitWidth

    Rectangle {
        id: backgroundRectangle
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        color: Style.colors.status.warn
        implicitHeight: mainLayout.implicitHeight
        implicitWidth: mainLayout.implicitWidth

        RowLayout {
            id: mainLayout
            anchors.fill: parent

            Icon {
                Layout.margins: Units.pt(8)
                Layout.preferredHeight: Units.pt(36)
                Layout.preferredWidth: Units.pt(36)
                backgroundColor: Style.getTextColor(color)
                color: backgroundRectangle.color
                font.family: Style.iconFontFamily
                text: Style.icons.exclamation
            }
            ColumnLayout {
                Layout.alignment: Qt.AlignVCenter
                Layout.fillWidth: true
                Layout.rightMargin: Units.pt(12)

                Text {
                    Layout.fillWidth: true
                    color: Style.getTextColor(backgroundRectangle.color)
                    font: Style.fonts.header
                    text: RobotManager.activeRobot.name
                }
                Text {
                    Layout.fillWidth: true
                    color: Style.getTextColor(backgroundRectangle.color)
                    font: Style.fonts.subHeader
                    text: {
                        let text = "Code: " + RobotManager.activeRobot.status.status_code + "\n";
                        return text + (RobotManager.activeRobot.status.status_message || "No status message");
                    }
                }
            }
        }
    }
}
