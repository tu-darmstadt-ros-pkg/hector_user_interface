import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Templates as T
import Ros2
import Hector.Controls
import Hector.InternalControls
import Hector.Utils
import Hector.Style
import Hector.MultiRobot

Button {
    id: robotDiagnosticsStatus
    checkable: false
    enabled: !!diagnosticTopLevelSubscriber.message && !diagnosticPopup.opened
    font.pointSize: 14
    text: !diagnosticTopLevelSubscriber.message ? "Unknown" : diagnosticTopLevelSubscriber.message.level === 0 ? "OK" : diagnosticTopLevelSubscriber.message.level === 1 ? "Warning" : "Error"

    background: Rectangle {
        color: {
            if (!diagnosticTopLevelSubscriber.message)
                return Style.colors.status.unknown;
            if (diagnosticTopLevelSubscriber.message.level === 0)
                return Style.handleMouseStates(robotDiagnosticsStatus, Style.colors.status.ok);
            if (diagnosticTopLevelSubscriber.message.level === 1)
                return Style.handleMouseStates(robotDiagnosticsStatus, Style.colors.status.warn);
            return Style.handleMouseStates(robotDiagnosticsStatus, Style.colors.status.error);
        }
    }

    onClicked: {
        if (diagnosticPopup.opened)
            diagnosticPopup.close();
        else
            diagnosticPopup.open();
    }

    Subscription {
        id: diagnosticTopLevelSubscriber
        topic: RobotManager.activeRobot.namespace + "/diagnostics_toplevel_state"
    }
    RobotDiagnosticStatusList {
        id: diagnosticPopup
        focus: true
        height: parent.height * 0.4
        parent: T.Overlay.overlay
        title: "Diagnostic messages"
        width: parent.width * 0.9
        x: (parent.width - width) / 2
        y: 5
    }
}
