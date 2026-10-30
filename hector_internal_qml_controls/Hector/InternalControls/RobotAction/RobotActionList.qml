import QtQuick 2.12
import QtQuick.Controls.Basic 2.2
import QtQuick.Layouts 1.1
import Hector.Actions 1.0
import Hector.InternalControls 1.0
import Hector.Controls 1.0
import Hector.MultiRobot 1.0
import Hector.Style 1.0
import Hector.Utils 1.0

ListView {
    id: root

    property bool dragActive: false
    property Item dragParent: root
    property bool editable: true
    property Robot robot: null

    signal editActionRequested(string uuid)
    signal removeActionRequested(string uuid)

    delegate: Item {
        property int index

        height: Units.pt(24)
        width: root.width

        RowLayout {
            anchors.fill: parent

            Text {
                Layout.margins: Units.pt(4)
                Layout.preferredWidth: Units.pt(8)
                font: Style.iconFontFamily
                text: modelData.icon || ''
            }
            Text {
                Layout.fillWidth: true
                text: modelData.name
            }
            Text {
                Layout.rightMargin: Units.pt(4)
                text: modelData.type
            }
        }
        Rectangle {
            color: Style.base.primary.color
            height: Units.pt(1)

            anchors {
                bottom: parent.bottom
                left: parent.left
                right: parent.right
            }
        }
        Menu {
            id: contextMenu
            MenuItem {
                text: "Edit"

                onTriggered: root.editActionRequested(modelData.uuid)
            }
            MenuItem {
                text: "Delete"

                onTriggered: root.removeActionRequested(modelData.uuid)
            }
        }
        RobotActionExecutor {
            id: robotActionExecutor
            robot: root.robot

            action: RobotAction {
                anonymous: Conversions.toBoolean(modelData.anonymous)
                evaluateParams: Conversions.toBoolean(modelData.evaluateParams)
                icon: modelData.icon
                messageType: modelData.messageType
                name: modelData.name
                parallel: Conversions.toBoolean(modelData.parallel)
                params: modelData.params
                subactions: modelData.subactions
                topic: modelData.topic
                type: modelData.type
                uuid: modelData.uuid
            }
        }
        MouseArea {
            acceptedButtons: Qt.RightButton
            anchors.fill: parent

            onClicked: contextMenu.popup()
        }
        MouseArea {
            id: dragArea
            acceptedButtons: Qt.LeftButton
            anchors.fill: parent
            drag.target: previewButton

            // Drag and drop is somewhat weird, see: https://stackoverflow.com/questions/24532317/new-drag-and-drop-mechanism-does-not-work-as-expected-in-qt-quick-qt-5-3
            drag.onActiveChanged: {
                root.dragActive = drag.active;
                if (drag.active)
                    drag.target.Drag.start();
                else
                    drag.target.Drag.drop();
            }
            onClicked: robotActionExecutor.execute()
        }

        // Drag preview
        ActionButton {
            id: previewButton

            property var model: modelData

            Drag.dragType: Drag.None
            Drag.hotSpot.x: width / 2
            Drag.hotSpot.y: height / 2
            Drag.keys: ["RobotAction"]
            height: Units.pt(32)
            robotAction: robotActionExecutor.action
            visible: false
            width: Units.pt(100)
            z: 1000

            states: [
                State {
                    when: dragArea.drag.active

                    ParentChange {
                        parent: root.dragParent
                        target: previewButton
                    }
                    PropertyChanges {
                        target: previewButton
                        visible: true
                        x: previewButton.parent.mapFromItem(dragArea, dragArea.mouseX, 0).x - previewButton.width / 2
                        y: previewButton.parent.mapFromItem(dragArea, 0, dragArea.mouseY).y - previewButton.height / 2
                    }
                }
            ]
        }
    }
}
