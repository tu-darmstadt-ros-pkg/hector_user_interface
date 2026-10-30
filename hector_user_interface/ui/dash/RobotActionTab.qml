import QtQuick 2.3
import QtQuick.Controls.Basic 2.2
import QtQuick.Layouts 1.1
import Hector.InternalControls 1.0
import Hector.InternalControls.RobotAction 1.0
import Hector.Controls 1.0
import Hector.MultiRobot 1.0
import Hector.Style 1.0
import Hector.Utils 1.0
import Ros2 1.0

Rectangle {
    id: root

    property var actionStructure: ({
            "uuid": "root",
            "type": "directory",
            "content": []
        })
    property var actions: []
    property bool editable: true
    property Robot robot: RobotManager.activeRobot
    property var style

    signal actionStructureUpdated
    signal actionsUpdated

    Component.onDestruction: d.unregisterAllActions()
    onActionsChanged: d.registerActions()

    QtObject {
        id: config

        property real animationDuration: 300
        readonly property var serviceBlacklist: [/\/get_loggers$/, /\/set_loggers$/, /\/set_logger_level$/, /^\/rosapi\//]

        function isBlacklistedService(topic) {
            for (var k = 0; k < serviceBlacklist.length; ++k) {
                if (serviceBlacklist[k].test(topic))
                    return true;
            }
            return false;
        }
    }
    Item {
        anchors.fill: parent

        RobotActionStructureView {
            id: structureView
            anchors.bottomMargin: openDrawerButton.height
            anchors.fill: parent
            clip: true
            dragParent: appWindow
            minimumCellWidth: Units.pt(96)
            robot: root.robot
            structure: root.actionStructure

            onEditActionRequested: function (uuid) {
                addActionDialog.edit(d.getAction(uuid));
            }
            onStructureUpdated: {
                root.actionStructure = structure;
                root.actionStructureUpdated();
            }
        }
        Rectangle {
            id: allBehaviorsDrawer

            property bool open: false

            clip: true
            color: Style.background.content
            // Workaround for bug where if anchors.fill is used dragged items from the lower part of the list just disappear
            height: parent.height

            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                topMargin: open && !allBehaviorsListView.dragActive ? 0 : root.height - openDrawerButton.height

                Behavior on topMargin  {
                    enabled: !allBehaviorsListView.dragActive

                    NumberAnimation {
                        duration: config.animationDuration
                    }
                }
            }
            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                Rectangle {
                    id: openDrawerButton
                    Layout.fillWidth: true
                    color: root.style.primary.color
                    height: Style.button.defaultHeight

                    states: [
                        State {
                            when: allBehaviorsDrawer.open

                            AnchorChanges {
                                anchors.horizontalCenter: undefined
                                anchors.left: parent.left
                                target: openDrawerButtonText
                            }
                            PropertyChanges {
                                color: Style.background.content
                                target: openDrawerButton
                            }
                        }
                    ]
                    transitions: Transition {
                        AnchorAnimation {
                            duration: config.animationDuration
                        }
                        ColorAnimation {
                            duration: config.animationDuration
                        }
                    }

                    Text {
                        id: openDrawerButtonText
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.leftMargin: Units.pt(8)
                        anchors.verticalCenter: parent.verticalCenter
                        color: Style.getTextColor(parent.color)
                        font: Style.button.font
                        text: "All Behaviors"
                    }
                    // Add action button
                    Button {
                        id: addRobotActionButton
                        anchors.right: parent.right
                        anchors.rightMargin: allBehaviorsDrawer.open ? 0 : -width
                        flat: true
                        height: parent.height
                        text: Style.icons.plus
                        width: height

                        Behavior on anchors.rightMargin  {
                            PropertyAnimation {
                                duration: config.animationDuration * 2
                            }
                        }

                        onClicked: addActionDialog.open()

                        font {
                            bold: true
                            family: Style.iconFontFamily
                            pointSize: Units.pt(6)
                        }
                    }
                    // Divider
                    Rectangle {
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: -Units.pt(1)
                        anchors.left: parent.left
                        color: "black"
                        height: Units.pt(1)
                        width: Units.pt(80)
                    }
                    MouseArea {
                        anchors.fill: parent
                        enabled: !allBehaviorsDrawer.open

                        onClicked: allBehaviorsDrawer.open = true
                    }
                }
                RobotActionList {
                    id: allBehaviorsListView
                    Layout.fillHeight: true
                    Layout.fillWidth: true
                    clip: true
                    dragParent: appWindow
                    model: root.actions
                    robot: root.robot

                    onEditActionRequested: function (uuid) {
                        addActionDialog.edit(d.getAction(uuid));
                    }
                    onRemoveActionRequested: function (uuid) {
                        // TODO Ask sure
                        d.removeAction(uuid);
                    }
                }
                StyledButton {
                    Layout.fillWidth: true
                    style: root.style
                    text: "Close"

                    onClicked: allBehaviorsDrawer.open = false
                }
            }
        }
        EditRobotActionDialog {
            id: addActionDialog
            actions: root.actions

            onEditFinished: function (action) {
                if (!action) {
                    editItem = null;
                    return;
                }
                // Copy, Qt 6 ignores re-assigning the same array
                var actions = Array.from(root.actions);
                if (editItem) {
                    for (let prop in action)
                        editItem[prop] = action[prop];
                    root.robot.actionManager.updateAction(editItem);
                } else {
                    action.uuid = Uuid.generate();
                    actions.push(action);
                }
                root.actions = actions;
                root.actionsUpdated();
                editItem = null;
            }
        }
    }
    QtObject {
        id: d

        property var registeredUuids: []

        function getAction(key) {
            for (var i = 0; i < root.actions.length; ++i) {
                if (root.actions[i].uuid === key)
                    return root.actions[i];
            }
            Ros2.error("Tried to obtain an action using a key that does not exist. Your config seems to be broken!");
        }
        function registerActions() {
            if (!root.robot)
                return;
            unregisterAllActions();
            for (var i = 0; i < root.actions.length; ++i) {
                root.robot.actionManager.registerAction(root.actions[i]);
                registeredUuids.push(root.actions[i].uuid);
            }
        }
        function removeAction(uuid) {
            // Copy, Qt 6 ignores re-assigning the same array
            var actions = Array.from(root.actions);
            for (var i = 0; i < actions.length; ++i) {
                if (actions[i].uuid !== uuid)
                    continue;
                actions.splice(i, 1);
                break;
            }
            root.actions = actions;
            // Deep copy, see RobotActionStructureView.commitStructure
            root.actionStructure = JSON.parse(JSON.stringify(removeActionFromStructure(root.actionStructure, uuid)));
            structureView.structure = root.actionStructure;
            root.actionsUpdated();
            root.actionStructureUpdated();
        }
        function removeActionFromStructure(structure, uuid) {
            if (structure.type !== "directory")
                return structure.key !== uuid ? structure : undefined;
            for (var i = 0; i < structure.content.length; ++i) {
                structure.content[i] = removeActionFromStructure(structure.content[i], uuid);
            }
            structure.content = structure.content.filter(Boolean);
            return structure;
        }
        function unregisterAllActions() {
            if (!root.robot)
                return;
            for (var i = 0; i < registeredUuids.length; ++i) {
                var action = root.robot.actionManager.getAction(registeredUuids[i]);
                if (action)
                    root.robot.actionManager.unregisterAction(action);
            }
            registeredUuids = [];
        }
    }
}
