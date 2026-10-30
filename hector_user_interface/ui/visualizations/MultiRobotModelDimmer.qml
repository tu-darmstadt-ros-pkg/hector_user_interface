import QtQuick 2.3
import Hector.MultiRobot 1.0
import Hector.Utils 1.0

//! Dims the robot models discovered by the MultiRobotModel rviz display so that only the active
//! robot is drawn at full opacity. Does nothing if no MultiRobotModel display is configured.
NonVisualItem {
    id: root

    property real activeAlpha: 1.0
    readonly property Robot activeRobot: RobotManager.activeRobot
    property real inactiveAlpha: 0.5

    Component.onCompleted: d.apply()
    onActiveRobotChanged: d.apply()

    QtObject {
        id: d

        //! The MultiRobotModel display wrapper. Resolved lazily because the display may only appear
        //! once the rviz config is loaded and may be removed or replaced by the operator at any time.
        property var display: null

        function apply() {
            const display = resolveDisplay();
            if (!display)
                return;
            const activeNamespace = root.activeRobot ? root.activeRobot.namespace : "";
            for (let robotDisplay of display.displays) {
                // A child display is named only after it was initialized, hence an empty name means its
                // internal robot does not exist yet and writing Alpha would crash the display.
                if (!robotDisplay.name)
                    continue;
                robotDisplay.setPropertyValue("Alpha", robotDisplay.name === activeNamespace ? root.activeAlpha : root.inactiveAlpha);
            }
        }
        function resolveDisplay() {
            if (d.display && d.display.valid)
                return d.display;
            d.display = null;
            for (let candidate of rviz.displayManager.displays) {
                if (!candidate.valid || candidate.classId !== "hector_rviz_plugins/MultiRobotModel")
                    continue;
                d.display = candidate;
                break;
            }
            return d.display;
        }
    }

    //! Coalesces the burst of displaysChanged emissions caused by MultiRobotModel discovering
    //! several robots within one scan into a single update.
    Timer {
        id: applyTimer
        interval: 0

        onTriggered: d.apply()
    }

    // The MultiRobotModel display itself may appear, disappear or be replaced at the root.
    Connections {
        function onDisplaysChanged() {
            applyTimer.restart();
        }

        target: rviz.displayManager
    }

    // A robot was discovered or removed by the MultiRobotModel display.
    Connections {
        function onDisplaysChanged() {
            applyTimer.restart();
        }

        target: d.display
    }
}
