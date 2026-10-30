import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import Hector.InternalControls
import Hector.Controls
import Hector.MultiRobot
import Hector.Style
import Hector.Utils
import Ros2

Item {
    id: root

    property var actions
    property Robot robot: RobotManager.activeRobot
    property var selectedActions: []
    property var type

    function reset() {
        selectedActions = [];
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Units.pt(2)

        RowLayout {
            id: addAction
            Layout.margins: Units.pt(5)
            spacing: Units.pt(2)

            ComboBox {
                id: actionComboBox
                Layout.fillWidth: true
                Layout.preferredHeight: Units.pt(24)
                model: {
                    // Sort actions by name
                    let tmp = Array.from(root.actions);
                    tmp.sort(function (action1, action2) {
                            try {
                                if (action1.name.toLowerCase() < action2.name.toLowerCase())
                                    return -1;
                                if (action1.name.toLowerCase() > action2.name.toLowerCase())
                                    return 1;
                                return 0;
                            } catch (e) {
                                Ros2.error("ActionSelector: Ordering list failed" + e + "\nStack: \n---\n" + e.stack);
                                return 0;
                            }
                        });
                    return tmp;
                }
                textRole: "name"
            }
            Button {
                Layout.preferredHeight: Units.pt(24)
                text: "Add"

                onClicked: {
                    // .push() doesn't update the list
                    selectedActions = [...selectedActions, {
                            "name": actionComboBox.model[actionComboBox.currentIndex].name,
                            "action": actionComboBox.model[actionComboBox.currentIndex].uuid
                        }];
                    checkValid();
                }
            }
            Button {
                Layout.preferredHeight: Units.pt(24)
                text: "Clear"

                onClicked: {
                    actionSelector.reset();
                    checkValid();
                }
            }
        }
        Rectangle {
            Layout.fillHeight: true
            Layout.fillWidth: true
            Layout.margins: Units.pt(5)
            color: Style.background.container
            implicitHeight: subactionsListView.implicitHeight

            ListView {
                id: subactionsListView
                function moveActionOnList(i, direction) {
                    if (i == null)
                        return;
                    // Copies: Qt 6 emits no change signal when re-assigning the same array
                    switch (direction) {
                    case 'up':
                        if (i > 0) {
                            var aux = selectedActions.splice(i, 1);
                            selectedActions.splice(i - 1, 0, aux[0]);
                            selectedActions = [...selectedActions];
                        }
                        break;
                    case 'down':
                        if (i < selectedActions.length - 1) {
                            var aux = selectedActions.splice(i, 1);
                            selectedActions.splice(i + 1, 0, aux[0]);
                            selectedActions = [...selectedActions];
                        }
                    }
                }

                anchors.fill: parent
                anchors.margins: Units.pt(4)
                clip: true
                model: selectedActions

                delegate: ColumnLayout {
                    property var action: root.robot.actionManager.getAction(modelData.action)

                    height: Units.pt(30)
                    spacing: 0
                    width: parent.width

                    RowLayout {
                        Layout.fillHeight: true
                        Layout.fillWidth: true

                        Text {
                            id: fixedText
                            Layout.alignment: Qt.AlignVCenter
                            Layout.fillWidth: true
                            font: Style.fonts.subHeader
                            text: {
                                return modelData.name || (action && action.name) || "";
                            }
                        }
                        TextField {
                            id: editableText
                            Layout.alignment: Qt.AlignVCenter
                            Layout.fillWidth: true
                            text: fixedText.text
                            visible: false
                        }
                        Text {
                            Layout.alignment: Qt.AlignRight
                            font: Style.fonts.small
                            text: action && action.name || ""
                            visible: type === "toggle"
                        }
                        Button {
                            Layout.preferredWidth: Units.pt(30)
                            text: fixedText.visible ? Style.icons.edit : Style.icons.check
                            visible: type === "toggle"

                            onClicked: {
                                if (editableText.visible) {
                                    selectedActions[index].name = editableText.text;
                                    selectedActions = [...selectedActions];
                                }
                                editableText.visible = !editableText.visible;
                                fixedText.visible = !fixedText.visible;
                            }

                            font {
                                family: Style.iconFontFamily
                                pointSize: Units.pt(8)
                            }
                        }
                        Button {
                            Layout.preferredWidth: Units.pt(20)
                            text: "↑"

                            onClicked: subactionsListView.moveActionOnList(index, "up")
                        }
                        Button {
                            Layout.preferredWidth: Units.pt(20)
                            text: "↓"

                            onClicked: subactionsListView.moveActionOnList(index, "down")
                        }
                    }
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: Units.pt(1)
                        color: "#1E000000"
                        visible: (index !== subactionsListView.count - 1)
                    }
                }
            }
        }
    }
}
