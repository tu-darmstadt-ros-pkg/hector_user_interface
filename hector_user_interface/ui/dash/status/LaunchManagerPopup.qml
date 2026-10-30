import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import Ros2
import Hector.Controls
import Hector.InternalControls
import Hector.Utils
import Hector.Style
import Hector.MultiRobot
import "."

Dialog {
    id: root

    property Robot robot: RobotManager.activeRobot

    title: robot.name + " Launch Manager Status"

    RowLayout {
        anchors.fill: parent
        anchors.margins: Units.pt(8)
        spacing: Units.pt(8)

        LaunchManagerControl {
            Layout.fillHeight: true
            Layout.fillWidth: true
            launchManager: robot.launch_manager
        }
        LaunchManagerControl {
            Layout.fillHeight: true
            Layout.fillWidth: true
            launchManager: robot.driver_launch_manager
        }
    }
}
