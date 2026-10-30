import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import Ros2
import Hector.Controls
import Hector.InternalControls
import Hector.Utils
import Hector.Style
import Hector.MultiRobot

Item {
    id: root

    required property var launchManager

    implicitHeight: mainLayout.implicitHeight
    implicitWidth: mainLayout.implicitWidth

    ColumnLayout {
        id: mainLayout
        anchors.fill: parent
        spacing: Units.pt(4)

        Label {
            text: root.launchManager.name
        }
        RowLayout {
            Layout.fillWidth: true

            Text {
                text: "Current Launch Config: "
            }
            Text {
                font.bold: true
                text: root.launchManager.config ?? "None"
            }
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: Units.pt(4)

            Text {
                text: "On "
            }
            ComboBox {
                id: hostsComboBox
                Layout.fillWidth: true
                currentIndex: 0
                model: root.launchManager.hosts

                onCurrentValueChanged: configsComboBox.refresh()
            }
            Text {
                text: " launch "
            }
            ComboBox {
                id: configsComboBox
                function refresh() {
                    configsComboBox.model = ["Loading..."];
                    root.launchManager.getLaunchConfigs(hostsComboBox.currentText, function (configs) {
                            configsRefreshButton.animate = false;
                            configsComboBox.model = configs || [];
                        });
                }

                Layout.fillWidth: true
                model: ["Loading..."]
            }
            RefreshButton {
                id: configsRefreshButton
                onClicked: {
                    animate = true;
                    configsComboBox.refresh();
                }
            }
        }
        StyledButton {
            Layout.fillWidth: true
            enabled: !root.launchManager.loading
            text: "Launch"

            onClicked: {
                root.launchManager.loadLaunchConfig(hostsComboBox.currentText, configsComboBox.currentText);
            }
        }
        ListView {
            id: componentsListView
            Layout.fillHeight: true
            Layout.fillWidth: true
            clip: true
            model: root.launchManager.components

            ScrollBar.vertical: ScrollBar {
                active: true
                policy: ScrollBar.AsNeeded

                onActiveChanged: {
                    if (!active)
                        active = true; // Force to stay visible
                }
            }
            delegate: ColumnLayout {
                width: componentsListView.width

                Label {
                    font.bold: true
                    text: host
                }
                Label {
                    Layout.leftMargin: Units.pt(8)
                    text: "No components running."
                    visible: components.count === 0
                }
                Repeater {
                    model: components

                    delegate: ComponentStatus {
                        command: model.command
                        height: Units.pt(20)
                        name: model.name
                        status: model.status
                        width: parent.width
                    }
                }
            }
        }
        StyledButton {
            Layout.fillWidth: true
            text: "Refresh"

            onClicked: {
                componentsListView.model = root.launchManager.components;
            }
        }
    }
}
