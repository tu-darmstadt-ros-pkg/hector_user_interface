import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import Hector.Utils
import Hector.Style
import Ros2

Item {
    id: control

    property alias evaluateParams: evaluateParamsCheckBox.checked
    property string label
    property string messageType
    property alias params: paramTextArea.text
    property string type

    function initFromTopic(topic) {
        if (d.type == "service") {
            let result = Ros2.getServiceTypes(topic);
            if (!result || result.length == 0) {
                messageType = "";
                paramErrorText.showError("Failed to obtain service type!\nCheck the service name and make sure the node can see it!");
                return;
            }
            messageType = result[0];
        } else if (d.type == "behavior") {
            messageType = "flexbe_msgs/action/BehaviorExecution";
        } else if (d.type == "action") {
            let result = Ros2.getActionTypes(topic);
            if (!result || result.length == 0) {
                messageType = "";
                paramErrorText.showError("Failed to obtain action type!\nCheck the action name and make sure the node can see it!");
                return;
            }
            messageType = result[0];
        } else if (d.type == "topic") {
            let result = Ros2.getTopicTypes(topic);
            if (!result || result.length == 0) {
                messageType = "";
                paramErrorText.showError("Failed to obtain topic type!\nCheck the topic name and make sure the node can see it!");
                return;
            }
            messageType = result[0];
        } else if (d.type == "javascript" || d.type == "toggle") {
            messageType = "";
        }
    }
    function reset() {
        if (d.type == "javascript") {
            params = "// Enter javascript code to execute on button press here\n";
            return;
        }
        if (d.type == "toggle") {
            params = "// Mapping from 'msg' variable to index\nreturn null // simple switching";
            return;
        }
        if (!messageType) {
            params = "";
            return;
        }
        let emptyMessage = "";
        if (d.type == "service") {
            emptyMessage = JSON.stringify(Ros2.createEmptyServiceRequest(messageType), null, 2) || "";
        } else if (d.type == "action" || d.type == "behavior") {
            emptyMessage = JSON.stringify(Ros2.createEmptyActionGoal(messageType), null, 2) || "";
        } else {
            var msg = Ros2.createEmptyMessage(messageType);
            emptyMessage = JSON.stringify(msg, null, 2) || "";
        }
        if (evaluateParamsCheckBox.checked)
            params = "return (" + emptyMessage + ")";
        else
            params = emptyMessage;
    }
    function validate() {
        paramErrorText.visible = false;
        if (d.type == "javascript" || evaluateParams || d.type == "toggle")
            return true;
        try {
            JSON.parse(params);
        } catch (e) {
            paramErrorText.showError("Value is not valid JSON!");
            return false;
        }
        return true;
    }

    implicitHeight: gridLayout.implicitHeight
    implicitWidth: gridLayout.implicitWidth

    onMessageTypeChanged: reset()
    onTypeChanged: reset()

    QtObject {
        id: d

        property bool hasEvaluateParams: ["action", "behavior", "service", "topic"].includes(d.type)
        property string type: control.type && control.type.toLowerCase() || ""
    }
    GridLayout {
        id: gridLayout
        anchors.fill: parent
        columns: 2

        Text {
            font: Style.fonts.label
            text: label ? label : "Value"
        }
        Button {
            Layout.alignment: Qt.AlignRight
            Layout.preferredHeight: Units.pt(24)
            leftPadding: Units.pt(8)
            rightPadding: Units.pt(8)
            text: "Reset"

            onClicked: control.reset()
        }
        Text {
            id: paramErrorText
            function showError(msg) {
                text = msg;
                visible = true;
            }

            Layout.columnSpan: 2
            color: "red"
            font: Style.fonts.small
            visible: false
        }
        CheckBox {
            id: evaluateParamsCheckBox
            Layout.columnSpan: 2
            Layout.fillWidth: true
            text: "Evaluate params"
            visible: d.hasEvaluateParams
        }
        Rectangle {
            Layout.columnSpan: 2
            Layout.fillHeight: true
            Layout.fillWidth: true

            border {
                color: "black"
                width: 1
            }
            ScrollView {
                anchors.fill: parent

                TextArea {
                    id: paramTextArea

                    property bool evaluateParams: d.hasEvaluateParams && evaluateParamsCheckBox.checked

                    cursorVisible: focus
                    height: Units.pt(40)
                    selectByMouse: true
                    text: ""

                    onEvaluateParamsChanged: {
                        if (evaluateParams) {
                            try {
                                JSON.parse(text);
                            } catch (e) {
                                return;
                            } // If valid JSON, replace it with simple return
                            text = "return (" + text + ")";
                        } else if (text.startsWith("return (")) {
                            let removedText = text.substr(8).slice(0, -1);
                            try {
                                JSON.parse(removedText);
                            } catch (e) {
                                return;
                            } // If return extension can be simply reversed, we do that
                            text = removedText;
                        }
                    }
                }
            }
        }
    }
}
