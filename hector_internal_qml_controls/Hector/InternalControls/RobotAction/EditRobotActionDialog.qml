import QtQuick 2.3
import QtQuick.Controls.Basic 2.2
import QtQuick.Templates as T
import QtQuick.Layouts 1.1
import Hector.InternalControls 1.0
import Hector.Controls 1.0
import Hector.Utils 1.0
import Hector.Style 1.0
import Ros2 1.0

Dialog {
    id: root

    property var actions: []
    property var editItem: null

    //! Emitted when editing is finished. Called with false if editing was canceled.
    signal editFinished(var item)

    function checkValid() {
        let valid = true;
        if (["composite", "toggle"].includes(typeComboBox.currentType)) {
            valid = actionSelector.selectedActions.length > 0;
        } else {
            valid = valid && typeComboBox.currentIndex >= 0;
            valid = valid && paramsEditor.validate();
        }
        nameErrorText.visible = false;
        if (nameTextField.text == "") {
            valid = false;
            nameErrorText.showError("Name is required!");
        }
        let button = root.standardButton(Dialog.Ok);
        if (button)
            button.enabled = valid;
        return valid;
    }
    function edit(item) {
        editItem = item;
        nameTextField.text = item && item.name || "";
        iconButton.text = item && item.icon || "Select icon";
        let type = item && item.type || null;
        if (type === "action" && item.messageType === "flexbe_msgs/action/BehaviorExecution") {
            type = "behavior";
        }
        var index = typeComboBox.find(type, Qt.MatchFixedString);
        topicComboBox.currentTopic = item && item.topic || "";
        topicComboBox.editText = item && item.topic || "";
        typeComboBox.currentIndex = Math.max(0, index);
        if (["composite", "toggle"].includes(type))
            actionSelector.selectedActions = item.subactions;
        parallelCheckbox.checked = Conversions.toBoolean(item && item.parallel);
        topicFeedbackCheckBox.checked = type == "toggle" && !!item.topic;
        paramsEditor.messageType = item && item.messageType || "";
        var evaluateParams = false;
        if (item && item.evaluateParams) {
            evaluateParams = typeof item.evaluateParams === "string" ? item.evaluateParams.toLowerCase() !== "false" : !!item.evaluateParams;
        }
        paramsEditor.evaluateParams = evaluateParams;
        paramsEditor.params = item && item.params || "";
        open();
    }
    function resetFields() {
        nameTextField.text = "";
        iconButton.text = "Select icon";
        paramsEditor.params = "";
        paramsEditor.evaluateParams = false;
        paramsEditor.messageType = "";
        typeComboBox.currentIndex = 0;
        topicComboBox.editText = "";
        parallelCheckbox.checked = false;
        topicFeedbackCheckBox.checked = false;
        actionSelector.reset();
    }

    closePolicy: Popup.NoAutoClose
    focus: true
    height: Units.pt(480)
    parent: T.Overlay.overlay
    standardButtons: Dialog.Ok | Dialog.Cancel
    title: "Add Robot Control Action"
    width: Units.pt(480)
    // Center dialog
    x: parent.x + (parent.width - width) / 2
    y: parent.y + (parent.height - height) / 2

    onAboutToShow: {
        topicComboBox.reload();
    }
    onAccepted: {
        if (!checkValid()) {
            if (nameTextField.text === "")
                nameTextField.focus = true;
            visible = true;
            return;
        }
        let type = typeComboBox.currentType;
        if (type == "behavior")
            type = "action";
        let messageType = paramsEditor.messageType;
        let topic = topicComboBox.currentTopic;
        if (type === "toggle" && !topicFeedbackCheckBox.checked)
            topic = "";
        root.editFinished({
                "name": nameTextField.text,
                "icon": iconButton.text.length < 5 ? iconButton.text : '',
                "type": type,
                "value": "",
                "topic": topic,
                "messageType": messageType,
                "params": paramsEditor.params,
                "evaluateParams": paramsEditor.evaluateParams,
                "subactions": actionSelector.selectedActions,
                "parallel": parallelCheckbox.checked
            });
        resetFields();
    }
    onRejected: {
        root.editFinished(false);
        resetFields();
    }

    SelectIconDialog {
        id: selectIconDialog
        onAccepted: {
            iconButton.text = icon;
        }
    }
    GridLayout {
        anchors.fill: parent
        columns: 2

        // === NAME ===
        Text {
            font: Style.fonts.label
            text: "Name:"
        }
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: Units.pt(24)

            TextField {
                id: nameTextField
                Layout.fillWidth: true
                Layout.preferredHeight: Units.pt(24)
                cursorVisible: focus
                selectByMouse: true

                onTextChanged: root.checkValid()
            }
            Button {
                id: iconButton
                Layout.preferredHeight: Units.pt(24)
                Layout.preferredWidth: text.length < 5 ? 2 * height : -1
                font: Style.iconFontFamily
                text: 'Select icon'

                onClicked: {
                    if (text.length < 5)
                        selectIconDialog.icon = text;
                    selectIconDialog.open();
                }
            }
        }
        Text {
            id: nameErrorText
            function showError(msg) {
                text = msg;
                visible = true;
            }

            Layout.columnSpan: 2
            color: "red"
            visible: false
        }

        // === TYPE ===
        Text {
            font: Style.fonts.label
            text: "Type:"
        }
        ComboBox {
            id: typeComboBox

            property string currentType: currentText.toLowerCase()

            Layout.fillWidth: true
            Layout.preferredHeight: Units.pt(24)
            editable: false
            model: ["Action", "Behavior", "Composite", "JavaScript", "Service", "Toggle", "Topic"]

            // onAccepted only fires for editable combo boxes
            onActivated: root.checkValid()
        }
        SectionHeader {
            Layout.columnSpan: 2
            Layout.fillWidth: true
            Layout.topMargin: Units.pt(8)
            font: Style.fonts.label
            text: "Configuration"
        }

        // === COMPOSITE AND TOGGLE ===
        ColumnLayout {
            Layout.columnSpan: 2
            Layout.fillHeight: true
            Layout.fillWidth: true
            visible: ["composite", "toggle"].includes(typeComboBox.currentType)

            ActionSelector {
                id: actionSelector
                Layout.fillHeight: true
                Layout.fillWidth: true
                Layout.minimumHeight: Units.pt(40)
                actions: root.actions
                type: typeComboBox.currentType

                onSelectedActionsChanged: root.checkValid()
            }
            CheckBox {
                id: parallelCheckbox
                Layout.fillWidth: true
                Layout.preferredHeight: Units.pt(24)
                font: Style.fonts.label
                text: "Parallel"
                visible: typeComboBox.currentType === "composite"
            }
            CheckBox {
                id: topicFeedbackCheckBox
                Layout.columnSpan: 2
                Layout.fillWidth: true
                Layout.preferredHeight: Units.pt(24)
                font: Style.fonts.label
                text: "Topic Feedback"
                visible: typeComboBox.currentType === "toggle"
            }
        }

        // === TOPIC ===
        Text {
            font: Style.fonts.label
            text: "Topic:"
            visible: topicComboBox.visible
        }
        TopicComboBox {
            id: topicComboBox

            property string currentTopic

            Layout.fillWidth: true
            autoLoad: true
            editable: true
            // For behaviors show only actions that accept BehaviorExecutionAction
            messageType: typeComboBox.currentType == "behavior" ? "flexbe_msgs/action/BehaviorExecution" : ""
            type: {
                switch (typeComboBox.currentType) {
                case "behavior":
                case "action":
                    return TopicComboBox.Action;
                case "service":
                    return TopicComboBox.Service;
                case "toggle":
                case "topic":
                default:
                    return TopicComboBox.Topic;
                }
            }
            visible: {
                if (["action", "behavior", "service", "topic"].includes(typeComboBox.currentType))
                    return true;
                if (typeComboBox.currentType == "toggle")
                    return topicFeedbackCheckBox.checked;
                return false;
            }

            onEditTextChanged: {
                if (currentTopic && currentTopic == editText)
                    return;
                currentTopic = editText;
                paramsEditor.initFromTopic(editText);
            }
        }

        // === VALUE ===
        RobotActionParamsEditor {
            id: paramsEditor
            Layout.columnSpan: 2
            Layout.fillHeight: true
            Layout.fillWidth: true
            Layout.minimumHeight: Units.pt(40)
            type: typeComboBox.currentType
            visible: {
                if (["action", "behavior", "javascript", "service", "topic"].includes(typeComboBox.currentType))
                    return true;
                if (typeComboBox.currentType == "toggle")
                    return topicFeedbackCheckBox.checked;
                return false;
            }

            onEvaluateParamsChanged: root.checkValid()
            onParamsChanged: root.checkValid()
        }
    }
}
