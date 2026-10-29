import QtQuick 2.8
import QtQuick.Controls 2.1
import QtQuick.Layouts 1.1
import Hector.Actions 1.0
import Hector.Controls 1.0
import Hector.InternalControls 1.0
import Hector.InternalControls.RobotAction 1.0
import Hector.Style 1.0
import Hector.Utils 1.0
import Ros2 1.0

RowLayout {
    id: control

    property alias active: driveToButton.active
    property var style
    property var waypointTool

    height: driveToButton.implicitHeight

    RowLayout {
        spacing: 0

        Rectangle {
            Layout.fillHeight: true
            color: Style.getTextColor(control.style.primary.color)
            implicitWidth: waypointsCount.implicitWidth

            Text {
                id: waypointsCount
                anchors.centerIn: parent
                color: control.style.primary.color
                leftPadding: Units.pt(8)
                rightPadding: Units.pt(4)
                text: (control.waypointTool && control.waypointTool.tool.waypoints.length || 0) + " Waypoints"

                font {
                    pointSize: 12
                    weight: Font.Bold
                }
            }
        }
        StyledButton {
            Layout.fillHeight: true
            Layout.preferredWidth: height
            style: control.style

            contentItem: AutoSizeText {
                anchors.fill: parent
                text: parent.hovered ? Style.icons.trashOpen : Style.icons.trash

                font {
                    family: Style.iconFontFamily
                }
            }

            onClicked: control.waypointTool.tool.clearWaypoints()
        }
    }
    ActionButton {
        id: driveToButton
        Layout.minimumWidth: Units.pt(104)
        robot: activeRobot
        style: control.style

        robotAction: RobotAction {
            id: driveAction
            name: 'Drive to waypoints'
            parallel: false
            // One NavigateToPose subaction per waypoint, executed sequentially.
            subactions: {
                if (!waypointTool || !activeRobot || waypointTool.tool.waypoints.length < 1) {
                    return [];
                }
                var subs = [];
                var topic = activeRobot.namespace + '/navigate_to_pose';
                for (const w_pose of waypointTool.tool.waypoints) {
                    subs.push({
                            "action": {
                                "name": 'Navigate to pose',
                                "type": 'action',
                                "topic": topic,
                                "messageType": 'nav2_msgs/action/NavigateToPose',
                                "evaluateParams": true,
                                "params": function () {
                                    const q = w_pose.orientation;
                                    return ({
                                            "#messageType": "nav2_msgs/action/NavigateToPose_Goal",
                                            "behavior_tree": "",
                                            "pose": {
                                                "header": {
                                                    "stamp": Ros2.now(),
                                                    "frame_id": waypointTool.tool.frame
                                                },
                                                "pose": {
                                                    "position": w_pose.position,
                                                    "orientation": {
                                                        "w": q.scalar,
                                                        "x": q.x,
                                                        "y": q.y,
                                                        "z": q.z
                                                    }
                                                }
                                            }
                                        });
                                }
                            }
                        });
                }
                return subs;
            }
            type: 'composite'

            // The composite is registered once; push subaction changes to the action manager so
            // the registered copy stays in sync with the current waypoints.
            onSubactionsChanged: if (activeRobot)
                activeRobot.actionManager.updateAction(driveAction)
        }
    }
}
