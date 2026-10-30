import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import Hector.Controls
import Hector.InternalControls
import Hector.Style
import Hector.Utils
import Ros2

Rectangle {
    id: root

    property var parameters: []
    property var style

    signal parametersUpdated

    ColumnLayout {
        anchors.fill: parent

        ListView {
            Layout.fillHeight: true
            Layout.fillWidth: true
            clip: true
            model: parameters
            spacing: Units.pt(2)

            delegate: Rectangle {
                color: Style.background.content
                implicitHeight: itemLayout.implicitHeight + Units.pt(8)
                width: parent.width

                RowLayout {
                    id: itemLayout
                    anchors {
                        bottomMargin: Units.pt(4)
                        fill: parent
                        leftMargin: Units.pt(8)
                        rightMargin: Units.pt(8)
                        topMargin: Units.pt(4)
                    }
                    Text {
                        id: paramNameText
                        Layout.alignment: Qt.AlignVCenter
                        Layout.preferredWidth: Units.pt(96)
                        elide: Text.ElideRight
                        text: modelData.name

                        SimpleToolTip {
                            text: modelData.name
                            visible: parent.truncated
                        }
                    }
                    Loader {
                        id: loader

                        property DynamicReconfigureParameter parameter: DynamicReconfigureParameter {
                            name: modelData.parameter
                            namespace: modelData.namespace
                        }

                        Layout.alignment: parameter.type == DynamicReconfigureParameter.Bool ? Qt.AlignRight : Qt.AlignVCenter
                        Layout.fillWidth: parameter.type != DynamicReconfigureParameter.Bool && parameter.type != DynamicReconfigureParameter.Uninitialized
                        sourceComponent: {
                            switch (parameter.type) {
                            case DynamicReconfigureParameter.Double:
                                return sliderComponent;
                            case DynamicReconfigureParameter.Bool:
                                return checkboxComponent;
                            case DynamicReconfigureParameter.Int:
                                return sliderComponent;
                            case DynamicReconfigureParameter.String:
                                return textfieldComponent;
                            case DynamicReconfigureParameter.Enum:
                                return comboBoxComponent;
                            case DynamicReconfigureParameter.Uninitialized:
                                return uninitializedComponent;
                            default:
                                Ros2.error("SettingsTab: unsupported param type " + modelData.type);
                                return;
                            }
                        }
                    }
                }
                Rectangle {
                    color: Style.base.primary.color
                    height: Units.pt(1)
                    visible: index != (parameters.length - 1)

                    anchors {
                        bottom: parent.bottom
                        bottomMargin: Units.pt(-0.5)
                        left: parent.left
                        right: parent.right
                    }
                }
            }
        }
        StyledButton {
            id: editButton
            Layout.fillWidth: true
            Layout.preferredHeight: Units.pt(24)
            style: root.style
            text: "Edit Quick Settings"

            onClicked: dynamicReconfigureDialog.edit(root.parameters)
        }
    }
    DynamicReconfigureDialog {
        id: dynamicReconfigureDialog
        onSelectionFinished: function (result) {
            parameters = result;
            root.parametersUpdated();
        }
    }
    Component {
        id: sliderComponent
        RowLayout {
            Text {
                Layout.preferredWidth: Units.pt(36)
                elide: Text.ElideRight
                text: parameter.min || 0
            }
            Slider {
                id: slider
                Layout.fillWidth: true
                from: parameter.min || 0
                stepSize: parameter.type == DynamicReconfigureParameter.Int ? 1 : 0
                to: parameter.max || 1
                value: parameter.value || 0.5

                background: Rectangle {
                    color: Style.background.container
                    height: Units.pt(4)
                    radius: height / 2
                    width: slider.availableWidth
                    x: slider.leftPadding
                    y: slider.topPadding + slider.availableHeight / 2 - height / 2

                    // Colored background until slider position
                    Rectangle {
                        color: style.primary.color
                        height: parent.height
                        radius: height / 2
                        width: slider.visualPosition * parent.width
                    }
                }
                handle: Rectangle {
                    border.color: style.primary.color
                    color: slider.pressed ? Style.background.container : Style.background.content
                    implicitHeight: Units.pt(8)
                    implicitWidth: Units.pt(12)
                    radius: Units.pt(4)
                    x: slider.leftPadding + slider.visualPosition * (slider.availableWidth - width)
                    y: slider.topPadding + slider.availableHeight / 2 - height / 2
                }

                onMoved: parameter.value = value
            }
            Text {
                Layout.preferredWidth: Units.pt(36)
                elide: Text.ElideRight
                text: parameter.max || 1
            }
            TextField {
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredWidth: Units.pt(40)
                maximumLength: 5
                selectByMouse: true
                text: parameter.value || 0.5
                validator: parameter.type == DynamicReconfigureParameter.Int ? intValidator : doubleValidator

                onAccepted: parameter.value = parseFloat(text)

                DoubleValidator {
                    id: doubleValidator
                }
                IntValidator {
                    id: intValidator
                }
            }
        }
    }
    Component {
        id: checkboxComponent
        CheckBox {
            Layout.alignment: Qt.AlignRight
            checked: parameter.value || false
            icon.color: style.primary.color

            onToggled: parameter.value = checked
        }
    }
    Component {
        id: textfieldComponent
        TextField {
            text: parameter.value || ""

            onAccepted: parameter.value = text
        }
    }
    Component {
        id: comboBoxComponent
        ComboBox {
            currentIndex: parameter.enumOptions.findIndex(opt => opt.value === parameter.value)
            model: parameter.enumOptions
            textRole: "name"

            onActivated: function (index) { parameter.value = parameter.enumOptions[index].value }
        }
    }
    Component {
        id: uninitializedComponent
        Text {
            text: "Loading parameter..."
        }
    }
}
