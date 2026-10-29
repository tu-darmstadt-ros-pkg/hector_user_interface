import QtQuick 2.3
import QtQuick.Controls 2.1
import Ros2 1.0
import Hector.Controls 1.0
import Hector.InternalControls 1.0
import Hector.Utils 1.0
import Hector.Style 1.0
import Hector.MultiRobot 1.0

StyledButton {
    id: root
    checkable: false
    font.pointSize: 12
    padding: 0
    text: RobotManager.activeRobot.launch_manager.config

    onClicked: {
        if (launchManagerPopup.opened)
            launchManagerPopup.close();
        else
            launchManagerPopup.open();
    }

    SimpleToolTip {
        text: "Launch Config"
    }
    LaunchManagerPopup {
        id: launchManagerPopup
        focus: true
        height: parent.height * 0.6
        parent: ApplicationWindow.overlay
        width: parent.width * 0.9
        x: (parent.width - width) / 2
        y: 5
    }
}
