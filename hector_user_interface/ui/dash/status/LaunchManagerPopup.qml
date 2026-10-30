import QtQuick 2.3
import QtQuick.Controls.Basic 2.1
import QtQuick.Layouts 1.1
import Ros2 1.0
import Hector.Controls 1.0
import Hector.InternalControls 1.0
import Hector.Utils 1.0
import Hector.Style 1.0
import Hector.MultiRobot 1.0
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
