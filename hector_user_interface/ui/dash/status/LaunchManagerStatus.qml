import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Templates as T
import Ros2
import Hector.Controls
import Hector.InternalControls
import Hector.Utils
import Hector.Style
import Hector.MultiRobot

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
        parent: T.Overlay.overlay
        width: parent.width * 0.9
        x: (parent.width - width) / 2
        y: 5
    }
}
