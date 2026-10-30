import QtQml
import QtQuick
import Hector.MultiRobot
import Hector.Utils

//! Creates the announced visualization displays for all discovered robots.
//! Instances are managed by robot_id and reused across RobotManager.robots
//! reassignments. A newly discovered robot must not tear down and rebuild the
//! displays of the robots already present, which an Instantiator would do since
//! it recreates every delegate whenever its JS-array model is reassigned.
NonVisualItem {
    id: root

    // robot_id -> RobotVisualizationDisplays instance.
    property var displaysByRobotId: ({})

    function sync() {
        let present = {};
        for (let robot of RobotManager.robots) {
            present[robot.robot_id] = true;
            if (!root.displaysByRobotId[robot.robot_id]) {
                root.displaysByRobotId[robot.robot_id] = displaysComponent.createObject(root, {
                        "robot": robot
                    });
            }
        }
        for (let id in root.displaysByRobotId) {
            if (id in present)
                continue;
            root.displaysByRobotId[id].destroy();
            delete root.displaysByRobotId[id];
        }
    }

    Component.onCompleted: sync()

    Component {
        id: displaysComponent
        RobotVisualizationDisplays {
        }
    }
    Connections {
        function onRobotsChanged() {
            root.sync();
        }

        target: RobotManager
    }
}
