import QtQuick
import QtQuick.Controls.Basic
import Hector.InternalControls
import Hector.MultiRobot
import Hector.Style
import Hector.Utils
import Ros2

StyledButton {
    id: control

    readonly property bool active: d.executor.execution && d.executor.execution.active
    property Robot robot
    property var robotAction: null

    ToolTip.delay: 500
    ToolTip.text: text
    ToolTip.visible: contentItem.truncated && control.hovered
    text: active ? "Cancel" : (robotAction && robotAction.name || "")

    background: Rectangle {
        clip: true
        //color: Style.handleMouseStates(control, control.checkable ? control.buttonStyle.uncheckedColor : control.buttonStyle.color, control.buttonStyle.checkedColor)
        color: control.active ? Style.handleMouseStates(control, Style.activeStyle.primary.color) : Style.handleMouseStates(control, Style.base.primary.color)
        implicitHeight: Units.pt(20)
        implicitWidth: Units.pt(50)
        opacity: enabled ? 1 : 0.3
        visible: !control.flat

        Text {
            color: '#44888888'
            fontSizeMode: Text.Fit
            height: parent.height * 1.5
            horizontalAlignment: Text.AlignHCenter
            minimumPointSize: 6
            text: control.robotAction && control.robotAction.icon || ''
            width: height
            x: -width / 4
            y: parent.height / 6

            font {
                family: Style.iconFontFamily
                pointSize: 100
            }
        }
        // Status text for toggle actions
        Text {
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Units.pt(2)
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.rightMargin: Units.pt(4)
            color: Style.getTextColor(parent.color)
            fontSizeMode: Text.Fit
            height: parent.height * 0.25
            horizontalAlignment: Text.AlignRight
            minimumPointSize: 6
            opacity: 0.6
            text: d.executor.state
            width: parent.width

            font {
                pointSize: 100
            }
        }
    }

    onClicked: {
        if (!robotAction)
            return;
        if (d.executor.active)
            d.executor.cancel();
        else
            d.executor.execute();
    }

    QtObject {
        id: d

        property RobotActionExecutor executor: RobotActionExecutor {
            action: control.robotAction
            robot: control.robot
        }
    }
}
