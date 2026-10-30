import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Templates as T
import QtQuick.Layouts
import Hector.Controls
import Hector.MultiRobot
import Hector.Style
import Hector.Utils

Rectangle {
    id: root
    color: Style.activeStyle.primary.color
    implicitHeight: Units.pt(16)
    visible: d.driveMode != ""

    QtObject {
        id: d

        readonly property string driveMode: RobotManager.activeRobot ? RobotManager.activeRobot.joyProfile : ""
        readonly property bool reverse: RobotManager.activeRobot ? RobotManager.activeRobot.teleopDriveReversed : false
    }
    RowLayout {
        anchors.fill: parent

        Rectangle {
            Layout.fillHeight: true
            Layout.preferredWidth: height
            color: Style.getTextColor(root.color)

            AutoSizeText {
                color: root.color
                font.family: Style.iconFontFamily
                margins: Units.pt(2)
                text: Style.icons.gamepad
            }
        }
        Text {
            Layout.fillHeight: true
            Layout.fillWidth: true
            Layout.margins: Units.pt(2)
            color: Style.getTextColor(root.color)
            font.pointSize: 100
            fontSizeMode: Text.Fit
            horizontalAlignment: Text.AlignHCenter
            minimumPointSize: 6
            text: d.driveMode
        }
        Rectangle {
            Layout.fillHeight: true
            Layout.preferredWidth: height
            color: Style.getTextColor(root.color)
            opacity: d.reverse ? 1 : 0

            AutoSizeText {
                color: root.color
                font.weight: Font.Bold
                margins: Units.pt(2)
                text: "R"
            }
        }
    }
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor

        onClicked: gamepadMappingPopup.opened ? gamepadMappingPopup.close() : gamepadMappingPopup.open()
    }
    SimpleToolTip {
        text: "Gamepad Mapping"
    }
    GamepadMappingPopup {
        id: gamepadMappingPopup
        focus: true
        height: parent.height * 0.8
        modal: true
        parent: T.Overlay.overlay
        width: parent.width * 0.8
        x: (parent.width - width) / 2
        y: (parent.height - height) / 3
    }
}
