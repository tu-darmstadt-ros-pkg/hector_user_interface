import QtQuick 2.3
import QtQuick.Controls.Basic 2.2
import QtQuick.Templates as T
import QtQuick.Layouts 1.1
import Hector.Controls 1.0
import Hector.Utils 1.0
import Hector.Style 1.0
import Ros2 1.0

Dialog {
    id: root
    signal selectionFinished(var items)

    function edit(parameters) {
        resetFields();
        d.selectedParams = parameters;
        d.loadParameters();
        open();
    }
    function resetFields() {
        filterTextField.text = "";
        paramsListView.visible = true;
        filterTextField.visible = true;
        editNameList.visible = false;
        d.selectedParams = [];
        d.parameters = [];
    }

    closePolicy: Popup.NoAutoClose
    focus: true
    height: Units.pt(400)
    modal: true
    parent: T.Overlay.overlay
    standardButtons: Dialog.Ok | Dialog.Cancel
    title: "Add Parameters to Quick Settings"
    width: Units.pt(500)
    x: parent.x + (parent.width - width) / 2
    y: parent.y + (parent.height - height) / 2

    onAccepted: {
        visible = true; // Need to change back to visible, otherwise paramsListView is also not visible
        // First accept switches to rename
        if (paramsListView.visible) {
            paramsListView.visible = false;
            filterTextField.visible = false;
            editNameList.model = d.parameters.filter(srv => srv.checked);
            editNameList.visible = true;
            return;
        }
        visible = false;
        d.selectedParams = d.parameters.filter(srv => srv.checked).map(srv => srv.data);
        root.selectionFinished(d.selectedParams);
        resetFields();
    }
    onRejected: resetFields()

    ColumnLayout {
        anchors.fill: parent

        TextField {
            id: filterTextField
            Layout.fillWidth: true
            placeholderText: qsTr("Filter...")
        }
        ListView {
            id: paramsListView
            Layout.fillHeight: true
            Layout.fillWidth: true
            clip: true
            model: d.filteredParameters
            spacing: Units.pt(2)

            delegate: Rectangle {
                color: Style.background.container
                height: itemMainLayout.implicitHeight
                width: parent.width

                RowLayout {
                    id: itemMainLayout
                    anchors.fill: parent

                    CheckBox {
                        id: delegateCheckbox
                        checked: modelData.checked

                        onCheckedChanged: d.updateParameterChecked(modelData.data.namespace, modelData.data.parameter, checked)
                    }
                    RowLayout {
                        Layout.fillWidth: true

                        Text {
                            Layout.fillWidth: true
                            Layout.rightMargin: Units.pt(8)
                            elide: Text.ElideMiddle
                            text: modelData.data.namespace + "/" + modelData.data.parameter

                            SimpleToolTip {
                                text: parent.text
                                visible: parent.truncated
                            }
                        }
                        Pill {
                            Layout.margins: Units.pt(4)
                            Layout.preferredWidth: Units.pt(48)
                            text: d.getNameForType(modelData.data.type)
                        }
                    }
                }
                MouseArea {
                    id: itemMouseArea
                    anchors.fill: parent

                    onClicked: delegateCheckbox.checked = !delegateCheckbox.checked
                }
            }

            BusyIndicator {
                id: loadingListIndicator
                anchors.centerIn: parent
            }
        }
        ListView {
            id: editNameList
            Layout.fillHeight: true
            Layout.fillWidth: true
            clip: true
            spacing: Units.pt(2)
            visible: false

            delegate: Rectangle {
                color: Style.background.container
                implicitHeight: itemLayout.implicitHeight + Units.pt(8)
                width: parent.width

                RowLayout {
                    id: itemLayout
                    anchors.fill: parent

                    Text {
                        Layout.fillWidth: true
                        Layout.margins: Units.pt(4)
                        Layout.preferredWidth: 1 // For equal division of available space
                        elide: Text.ElideMiddle
                        text: modelData.data.namespace + "/" + modelData.data.parameter

                        SimpleToolTip {
                            text: parent.text
                            visible: parent.truncated
                        }
                    }
                    TextField {
                        Layout.fillWidth: true
                        Layout.margins: Units.pt(4)
                        Layout.preferredWidth: 1
                        selectByMouse: true
                        text: modelData.data.name

                        onTextEdited: d.updateParameterName(modelData.data.namespace, modelData.data.parameter, text)
                    }
                }
            }
            header: RowLayout {
                height: Units.pt(24)
                width: parent.width

                Text {
                    Layout.preferredWidth: 1
                    font.bold: true
                    text: "Complete Name"
                }
                Text {
                    Layout.preferredWidth: 1
                    font.bold: true
                    text: "Custom Name"
                }
            }
        }
    }
    QtObject {
        id: d

        // Blacklist camera settings
        property var blacklist: new RegExp(/\/compressed\/|\/compressedDepth\/|\/theora\//)
        property var filteredParameters: {
            if (filterTextField.text.length == 0)
                return d.parameters;
            const searchText = filterTextField.text;
            return d.parameters.filter(srv => srv.data.parameter.includes(searchText) || srv.data.namespace.includes(searchText));
        }
        property var parameters: []
        property var reconfigureTopicRegex: new RegExp(/parameter_descriptions$/)
        property var selectedParams: []

        function getConfigForParam(namespace, parameter) {
            for (let p of d.selectedParams) {
                if (p.namespace !== namespace || p.parameter !== parameter)
                    continue;
                return {
                    "checked": true,
                    "name": p.name
                };
            }
            return {
                "checked": false,
                "name": parameter
            };
        }
        function getNameForType(type) {
            if (type == "str")
                return "string";
            return type;
        }
        function loadParameters() {
            let parameters = [];
            loadingListIndicator.running = true;
            let topics = new Set();
            for (let topic of Ros2.queryTopics("dynamic_reconfigure/ConfigDescription")) {
                if (!reconfigureTopicRegex.test(topic))
                    // skip topics that do not follow params structure
                    continue;
                if (blacklist.test(topic))
                    continue;
                topics.add(topic);
            }
            function sortFn(a, b) {
                // First sort by checked, then based on full parameter name
                return (a.checked && !b.checked) || (!b.checked && (a.data.namespace + a.data.parameter) < (b.data.namespace + b.data.parameter));
            }
            let promises = [];
            for (var topic of topics) {
                try {
                    let namespace = topic.substr(0, topic.length - 23); // Remove /parameter_descriptions suffix
                    let promise = new Promise(resolve => {
                        // Try to get parameter descriptions within 10 seconds
                        Ros2.waitForMessageAsync(topic, 10000, function (result) {
                                if (!result) {
                                    Ros2.error("Failed to get parameter descriptions for: " + namespace);
                                    resolve();
                                    return;
                                }
                                try {
                                    for (let group of result.groups.toArray()) {
                                        for (let parameter of group.parameters.toArray()) {
                                            const config = d.getConfigForParam(namespace, parameter.name);
                                            let data = {
                                                "data": {
                                                    "namespace": namespace,
                                                    "parameter": parameter.name,
                                                    "type": parameter.type,
                                                    "name": config.name
                                                },
                                                "checked": config.checked
                                            };
                                            HectorAlgorithms.insertSorted(parameters, data, sortFn);
                                        }
                                    }
                                } catch (e) {
                                    Ros2.error("Error while getting parameters for " + namespace + ": " + e);
                                }
                                resolve();
                            });
                    });
                    promises.push(promise);
                } catch (e) {
                    Ros2.error("DynamicReconfigureDialog: Error getting parameter description for " + namespace + "\nTrace: " + e);
                }
            }
            Promise.all(promises).then(() => {
                    d.parameters = parameters;
                    loadingListIndicator.running = false;
                });
        }
        function updateParameterChecked(namespace, parameter, checked) {
            let item = d.parameters.find(srv => srv.data.parameter === parameter && srv.data.namespace === namespace);
            if (!item)
                return;
            item.checked = checked;
        }
        function updateParameterName(namespace, parameter, name) {
            let item = d.parameters.find(srv => srv.data.parameter === parameter && srv.data.namespace === namespace);
            if (!item)
                return;
            item.data.name = name;
        }
    }
}
