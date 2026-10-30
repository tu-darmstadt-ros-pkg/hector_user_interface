import QtQuick 2.3
import QtQuick.Controls.Basic 2.2
import QtQuick.Layouts 1.1
import Hector.Controls 1.0
import Hector.InternalControls 1.0
import Hector.Style 1.0
import Hector.Utils 1.0

Rectangle {
    id: root

    property var configuration
    property bool locked: true

    //! Emitted with the new layouts array. The parent owns storage; assigning `configuration`
    //! here would break its binding to the active robot, so we never mutate it in place.
    signal configurationUpdated(var layouts)

    color: Style.background.container

    ColumnLayout {
        anchors.fill: root

        RowLayout {
            Layout.fillWidth: true

            Text {
                Layout.fillWidth: true
                font: Style.fonts.subHeader
                text: "Camera Layouts"
            }
            Button {
                Layout.preferredWidth: Units.pt(32)
                text: root.locked ? Style.icons.lockClosed : Style.icons.lockOpen

                onClicked: root.locked = !root.locked
            }
        }
        QtObject {
            id: d
            // Removes by index because modelData is a copy of the array entry, not the entry itself.
            function removeLayout(index) {
                root.configurationUpdated(root.configuration.filter(function (l, i) {
                            return i !== index;
                        }));
            }
        }
        ListView {
            id: cameraLayoutsListView
            Layout.fillHeight: true
            Layout.fillWidth: true
            clip: true
            model: configuration
            spacing: Units.pt(2)

            delegate: Rectangle {
                color: Style.background.content
                height: Units.pt(24)
                width: root.width

                Text {
                    anchors.centerIn: parent
                    text: modelData.layout_name
                }
                MouseArea {
                    acceptedButtons: Qt.LeftButton
                    anchors.fill: parent
                    hoverEnabled: true

                    onClicked: {
                        leftCameraView.transitionsEnabled = false;
                        rightCameraView.transitionsEnabled = false;
                        leftCameraView.selectCameraByName(modelData.left_cam);
                        rightCameraView.selectCameraByName(modelData.right_cam);
                        leftCameraView.transitionsEnabled = true;
                        rightCameraView.transitionsEnabled = true;
                    }
                }
                Button {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    flat: true
                    height: parent.height
                    visible: !locked
                    width: height

                    onClicked: d.removeLayout(index)

                    Icon {
                        anchors.fill: parent
                        flat: true
                        text: parent.hovered ? Style.icons.trashOpen : Style.icons.trash
                    }
                }
            }
            footer: RowLayout {
                spacing: 0
                visible: !locked
                width: parent.width

                TextField {
                    id: layoutNameTextField
                    Layout.fillWidth: true
                    Layout.topMargin: cameraLayoutsListView.spacing
                    hoverEnabled: true
                    placeholderText: qsTr("Name")
                }
                StyledButton {
                    Layout.preferredHeight: layoutNameTextField.height
                    Layout.topMargin: cameraLayoutsListView.spacing
                    style: Style.activeStyle
                    text: qsTr("Add")

                    onClicked: {
                        if (!layoutNameTextField.text)
                            return;
                        var layout = {};
                        layout.layout_name = layoutNameTextField.text;
                        layout.left_cam = leftCameraView.selectedCamera ? leftCameraView.selectedCamera.configuration.id : "";
                        layout.right_cam = rightCameraView.selectedCamera ? rightCameraView.selectedCamera.configuration.id : "";
                        layoutNameTextField.clear();
                        root.configurationUpdated((root.configuration || []).concat([layout]));
                    }
                }
            }
        }
    }
}
