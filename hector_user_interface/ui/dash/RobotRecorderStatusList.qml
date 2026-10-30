import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import Ros2
import Hector.Controls
import Hector.InternalControls
import Hector.Utils
import Hector.Style

Dialog {
    id: root

    property string activePreset: (statusMsg && statusMsg.active_preset) ? statusMsg.active_preset : ""
    property var applyConfigClient: nodeName ? Ros2.createServiceClient(nodeName + "/apply_config", "hector_recorder_msgs/srv/ApplyConfig") : null
    property string configText: "(none)"
    property string durationText: "00:00:00"
    property var getInfoClient: nodeName ? Ros2.createServiceClient(nodeName + "/get_recorder_info", "hector_recorder_msgs/srv/GetRecorderInfo") : null
    readonly property int idle: 0
    property string nodeName: (statusMsg && statusMsg.node_name) ? statusMsg.node_name : ""
    property string outputDirText: ""
    property var pauseClient: nodeName ? Ros2.createServiceClient(nodeName + "/pause_recording", "hector_recorder_msgs/srv/PauseRecording") : null
    readonly property int paused: 2

    // Onboard presets from the status message. The ROS array (qml_ros2_plugin::Array)
    // lacks JS Array methods, so copy it into a plain array for indexOf() etc.
    property var presetNames: toJsArray(statusMsg ? statusMsg.preset_names : null)
    property string recorderConfigPath: ""
    property int recorderState: (statusMsg && statusMsg.state !== undefined) ? statusMsg.state : idle
    readonly property int recording: 1
    property var resumeClient: nodeName ? Ros2.createServiceClient(nodeName + "/resume_recording", "hector_recorder_msgs/srv/ResumeRecording") : null
    property var splitClient: nodeName ? Ros2.createServiceClient(nodeName + "/split_bag", "hector_recorder_msgs/srv/SplitBag") : null
    property var startClient: nodeName ? Ros2.createServiceClient(nodeName + "/start_recording", "hector_recorder_msgs/srv/StartRecording") : null
    property var statusMsg: null
    property int statusSeq: 0
    property var stopClient: nodeName ? Ros2.createServiceClient(nodeName + "/stop_recording", "hector_recorder_msgs/srv/StopRecording") : null
    property var topics_lm: ListModel {
        id: topicsListModel
    }
    property string totalSizeText: "0 B"
    property int updatePeriodMs: 1000

    function applyPreset(name, restart) {
        if (!applyConfigClient)
            return;
        applyConfigClient.sendRequestAsync({
                "config_yaml": "",
                "preset_name": name,
                "restart": restart
            }, function (r) {
                if (!r || !r.success)
                    Ros2.error("Apply preset failed: " + (r ? r.message : "no response"));
            });
    }
    function asNumber(x) {
        if (x === undefined || x === null)
            return 0;
        if (typeof x === "number")
            return x;
        const n = Number(asText(x));
        return isNaN(n) ? 0 : n;
    }
    function asText(x) {
        if (x === undefined || x === null)
            return "";
        if (typeof x === "string")
            return x;
        if (typeof x === "number" || typeof x === "boolean")
            return "" + x;
        if (x.toString)
            return x.toString();
        return "" + x;
    }
    function durationSeconds(d) {
        if (!d || !d.toString)
            return 0;
        const s = d.toString();
        const m = /\(\s*([0-9]+(?:\.[0-9]+)?)/.exec(s);
        return m ? Number(m[1]) : 0;
    }
    function formatBytes(bytes) {
        let b = asNumber(bytes);
        const units = ["B", "KB", "MB", "GB", "TB"];
        let i = 0;
        while (b >= 1024 && i < units.length - 1) {
            b /= 1024;
            i++;
        }
        return b.toFixed(i === 0 ? 0 : 1) + " " + units[i];
    }
    function formatDurationFromSeconds(sec) {
        sec = Math.floor(asNumber(sec));
        let h = Math.floor(sec / 3600);
        let m = Math.floor((sec % 3600) / 60);
        let s = sec % 60;
        function pad(x) {
            return (x < 10 ? "0" : "") + x;
        }
        return pad(h) + ":" + pad(m) + ":" + pad(s);
    }
    function refreshModels() {
        if (!statusMsg) {
            topicsListModel.clear();
            outputDirText = "";
            configText = "(none)";
            durationText = "00:00:00";
            totalSizeText = "0 B";
            return;
        }
        outputDirText = asText(statusMsg.output_dir);
        configText = recorderConfigPath.length ? recorderConfigPath : "(none)";
        totalSizeText = formatBytes(asNumber(statusMsg.size));
        durationText = formatDurationFromSeconds(durationSeconds(statusMsg.duration));

        // Update the topic rows in place
        const n = (statusMsg.topics && statusMsg.topics.length) ? statusMsg.topics.length : 0;
        for (let i = 0; i < n; i++) {
            let t = statusMsg.topics.at(i);
            let row = {
                "topic": asText(t.topic),
                "msg_count": asNumber(t.msg_count),
                "frequency": asNumber(t.frequency)
            };
            if (i < topicsListModel.count) {
                let existing = topicsListModel.get(i);
                if (existing.topic !== row.topic) {
                    topicsListModel.set(i, row);
                } else {
                    if (existing.msg_count !== row.msg_count)
                        topicsListModel.setProperty(i, "msg_count", row.msg_count);
                    if (existing.frequency !== row.frequency)
                        topicsListModel.setProperty(i, "frequency", row.frequency);
                }
            } else {
                topicsListModel.append(row);
            }
        }

        // Drop any trailing rows that no longer exist in the incoming message.
        while (topicsListModel.count > n)
            topicsListModel.remove(topicsListModel.count - 1);
    }

    // Switch to a named onboard preset. While recording, confirm first (the
    // switch restarts into a fresh bag); when idle, apply immediately.
    function requestPresetSwitch(name) {
        if (!name || name === activePreset)
            return;
        if (recorderState === recording || recorderState === paused) {
            presetSwitchDialog.pendingPreset = name;
            presetSwitchDialog.open();
        } else {
            applyPreset(name, false);
        }
    }
    function toJsArray(rosArray) {
        let out = [];
        if (!rosArray || rosArray.length === undefined)
            return out;
        for (let i = 0; i < rosArray.length; i++)
            out.push(rosArray.at ? rosArray.at(i) : rosArray[i]);
        return out;
    }

    implicitHeight: Units.pt(300)
    implicitWidth: Units.pt(560)

    onGetInfoClientChanged: {
        if (getInfoClient) {
            getInfoClient.sendRequestAsync({}, function (r) {
                    if (r && r.config_path)
                        root.recorderConfigPath = r.config_path;
                });
        }
    }
    onOpened: refreshModels()
    onStatusSeqChanged: {
        if (opened)
            refreshModels();
    }

    Timer {
        interval: root.updatePeriodMs
        repeat: true
        running: root.opened
        triggeredOnStart: true

        onTriggered: root.refreshModels()
    }
    ColumnLayout {
        anchors.fill: parent
        spacing: Units.pt(10)

        GridLayout {
            Layout.fillWidth: true
            columnSpacing: Units.pt(24)
            columns: 2
            rowSpacing: Units.pt(6)

            ColumnLayout {
                Layout.column: 0
                Layout.fillWidth: true
                Layout.row: 0
                spacing: Units.pt(2)

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Units.pt(6)

                    Text {
                        Layout.fillWidth: true
                        font.bold: true
                        text: "Output dir"
                    }
                    ToolButton {
                        ToolTip.text: "Copy to clipboard"
                        ToolTip.visible: hovered
                        enabled: outputDirText.length > 0
                        text: ""

                        contentItem: Text {
                            anchors.centerIn: parent
                            font.family: Style.iconFontFamily
                            font.pixelSize: Units.pt(12)
                            horizontalAlignment: Text.AlignHCenter
                            opacity: parent.enabled ? 1.0 : 0.4
                            text: Style.icons.edit
                            verticalAlignment: Text.AlignVCenter
                        }

                        onClicked: rviz.copyTextToClipboard(outputDirText)
                    }
                }
                Text {
                    Layout.fillWidth: true
                    elide: Text.ElideMiddle
                    text: outputDirText
                    wrapMode: Text.NoWrap

                    MouseArea {
                        ToolTip.delay: 400
                        ToolTip.text: "Copy to clipboard"
                        ToolTip.visible: containsMouse
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true

                        onClicked: rviz.copyTextToClipboard(outputDirText)
                    }
                }
            }
            ColumnLayout {
                Layout.column: 1
                Layout.fillWidth: true
                Layout.maximumWidth: Math.floor((parent.width - parent.columnSpacing) / 2)
                Layout.row: 0
                spacing: Units.pt(2)

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Units.pt(6)

                    Text {
                        Layout.fillWidth: true
                        font.bold: true
                        text: "Config"
                    }
                    ToolButton {
                        ToolTip.text: "Copy to clipboard"
                        ToolTip.visible: hovered
                        enabled: configText.length > 0 && configText !== "(none)"
                        text: ""
                        visible: root.presetNames.length === 0

                        contentItem: Text {
                            anchors.centerIn: parent
                            font.family: Style.iconFontFamily
                            font.pixelSize: Units.pt(12)
                            horizontalAlignment: Text.AlignHCenter
                            opacity: parent.enabled ? 1.0 : 0.4
                            text: Style.icons.edit
                            verticalAlignment: Text.AlignVCenter
                        }

                        onClicked: rviz.copyTextToClipboard(configText)
                    }
                }

                // Preset selector when the recorder announces onboard presets;
                // otherwise fall back to the read-only config path.
                ComboBox {
                    id: presetCombo
                    Layout.fillWidth: true
                    ToolTip.delay: 400
                    ToolTip.text: "Switch the recorder's onboard logging preset"
                    ToolTip.visible: hovered
                    currentIndex: Math.max(0, root.presetNames.indexOf(root.activePreset))
                    displayText: root.activePreset === "" ? "(custom)" : currentText
                    enabled: applyConfigClient !== null
                    model: root.presetNames
                    visible: root.presetNames.length > 0

                    onActivated: function (index) {
                        root.requestPresetSwitch(root.presetNames[index]);
                    }
                }
                Text {
                    Layout.fillWidth: true
                    elide: Text.ElideMiddle
                    text: configText
                    visible: root.presetNames.length === 0
                    wrapMode: Text.NoWrap

                    MouseArea {
                        ToolTip.delay: 400
                        ToolTip.text: "Copy to clipboard"
                        ToolTip.visible: containsMouse
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true

                        onClicked: rviz.copyTextToClipboard(configText)
                    }
                }
            }
            RowLayout {
                Layout.column: 0
                Layout.fillWidth: true
                Layout.row: 1
                spacing: Units.pt(8)

                Text {
                    font.bold: true
                    text: "Duration:"
                }
                Text {
                    text: durationText
                }
            }
            RowLayout {
                Layout.column: 1
                Layout.fillWidth: true
                Layout.row: 1
                spacing: Units.pt(8)

                Text {
                    font.bold: true
                    text: "Total size:"
                }
                Text {
                    text: totalSizeText
                }
            }
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: Units.pt(8)

            Button {
                ToolTip.delay: 400
                ToolTip.text: "Start a new recording"
                ToolTip.visible: hovered
                enabled: recorderState === idle && startClient !== null

                contentItem: Row {
                    anchors.centerIn: parent
                    opacity: parent.enabled ? 1.0 : 0.4
                    spacing: Units.pt(4)

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        font.family: Style.iconFontFamily
                        font.pixelSize: Units.pt(10)
                        text: Style.icons.play
                        verticalAlignment: Text.AlignVCenter
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "START"
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                onClicked: startClient.sendRequestAsync({
                        "output_dir": "",
                        "recorded_by": ""
                    }, function (r) {
                        if (!r || !r.success)
                            Ros2.error("Start recording failed: " + (r ? r.message : "no response"));
                    })
            }
            Button {
                ToolTip.delay: 400
                ToolTip.text: "Pause recording"
                ToolTip.visible: hovered
                enabled: recorderState === recording || recorderState === paused

                contentItem: Row {
                    anchors.centerIn: parent
                    opacity: parent.enabled ? 1.0 : 0.4
                    spacing: Units.pt(4)

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        font.family: Style.iconFontFamily
                        font.pixelSize: Units.pt(10)
                        text: recorderState === paused ? Style.icons.play : Style.icons.pause
                        verticalAlignment: Text.AlignVCenter
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: recorderState === paused ? "RESUME" : "PAUSE"
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                onClicked: {
                    if (recorderState === recording && pauseClient) {
                        pauseClient.sendRequestAsync({}, function (r) {
                                if (!r || !r.success)
                                    Ros2.error("Pause recording failed: " + (r ? r.message : "no response"));
                            });
                    } else if (recorderState === paused && resumeClient) {
                        resumeClient.sendRequestAsync({}, function (r) {
                                if (!r || !r.success)
                                    Ros2.error("Resume recording failed: " + (r ? r.message : "no response"));
                            });
                    }
                }
            }
            Button {
                ToolTip.delay: 400
                ToolTip.text: "Stop the current recording"
                ToolTip.visible: hovered
                enabled: (recorderState === recording || recorderState === paused) && stopClient !== null

                contentItem: Row {
                    anchors.centerIn: parent
                    opacity: parent.enabled ? 1.0 : 0.4
                    spacing: Units.pt(4)

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        font.family: Style.iconFontFamily
                        font.pixelSize: Units.pt(10)
                        text: Style.icons.stop
                        verticalAlignment: Text.AlignVCenter
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "STOP"
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                onClicked: stopClient.sendRequestAsync({}, function (r) {
                        if (!r || !r.success)
                            Ros2.error("Stop recording failed: " + (r ? r.message : "no response"));
                    })
            }
            Button {
                ToolTip.delay: 400
                ToolTip.text: "Split the current bag file"
                ToolTip.visible: hovered
                enabled: recorderState === recording && splitClient !== null

                contentItem: Row {
                    anchors.centerIn: parent
                    opacity: parent.enabled ? 1.0 : 0.4
                    spacing: Units.pt(4)

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        font.family: Style.iconFontFamily
                        font.pixelSize: Units.pt(10)
                        text: Style.icons.flag
                        verticalAlignment: Text.AlignVCenter
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "SPLIT"
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                onClicked: splitClient.sendRequestAsync({}, function (r) {
                        if (!r || !r.success)
                            Ros2.error("Split bag failed: " + (r ? r.message : "no response"));
                    })
            }
        }
        RowLayout {
            Layout.fillWidth: true
            Layout.rightMargin: topicsListView.scrollBarInset
            spacing: Units.pt(10)

            Item {
                height: Units.pt(12)
                width: Units.pt(12)
            }
            Text {
                Layout.fillWidth: true
                elide: Text.ElideRight
                font.bold: true
                text: "Topic"
            }
            Text {
                Layout.preferredWidth: Units.pt(70)
                font.bold: true
                horizontalAlignment: Text.AlignRight
                text: "Msgs"
            }
            Text {
                Layout.preferredWidth: Units.pt(60)
                font.bold: true
                horizontalAlignment: Text.AlignRight
                text: "Hz"
            }
        }
        Rectangle {
            Layout.fillWidth: true
            color: "#E6E6E6"
            height: 1
        }
        ListView {
            id: topicsListView

            // Width taken up by the vertical scrollbar when it is shown
            property real scrollBarInset: topicsScrollBar.visible ? topicsScrollBar.width : 0

            Layout.fillHeight: true
            Layout.fillWidth: true
            boundsBehavior: Flickable.StopAtBounds
            clip: true
            model: topicsListModel
            spacing: Units.pt(6)

            ScrollBar.vertical: ScrollBar {
                id: topicsScrollBar
                policy: topicsListView.contentHeight > topicsListView.height ? ScrollBar.AlwaysOn : ScrollBar.AsNeeded
            }
            delegate: RowLayout {
                spacing: Units.pt(10)
                width: (ListView.view ? ListView.view.width : 0) - topicsListView.scrollBarInset

                Rectangle {
                    Layout.alignment: Qt.AlignVCenter
                    color: (msg_count > 0) ? "limegreen" : "red"
                    height: Units.pt(10)
                    radius: Units.pt(10)
                    width: Units.pt(10)

                    MouseArea {
                        ToolTip.delay: 400
                        ToolTip.text: (msg_count > 0) ? "Messages received" : "No messages received"
                        ToolTip.visible: containsMouse
                        acceptedButtons: Qt.NoButton
                        anchors.fill: parent
                        hoverEnabled: true
                    }
                }
                Text {
                    Layout.fillWidth: true
                    elide: Text.ElideMiddle
                    text: topic

                    MouseArea {
                        ToolTip.delay: 400
                        ToolTip.text: topic
                        ToolTip.visible: containsMouse
                        acceptedButtons: Qt.NoButton
                        anchors.fill: parent
                        hoverEnabled: true
                    }
                }
                Text {
                    Layout.preferredWidth: Units.pt(70)
                    horizontalAlignment: Text.AlignRight
                    text: msg_count
                }
                Text {
                    Layout.preferredWidth: Units.pt(60)
                    horizontalAlignment: Text.AlignRight
                    text: frequency.toFixed(1)
                }
            }
        }
    }

    // Confirm preset switch while recording (restarts into a fresh bag)
    Dialog {
        id: presetSwitchDialog

        property string pendingPreset: ""

        anchors.centerIn: parent

        // Fixed width avoids a binding loop between the Dialog's content-derived
        // implicitWidth and the wrapping Text's width.
        implicitWidth: Units.pt(400)
        modal: true
        standardButtons: Dialog.Cancel | Dialog.Ok
        title: "Switch preset while recording?"

        onAccepted: root.applyPreset(pendingPreset, true)

        // If dismissed without confirming, snap the combo back to the active preset.
        onRejected: presetCombo.currentIndex = Math.max(0, root.presetNames.indexOf(root.activePreset))

        Text {
            text: "Switching to \"" + presetSwitchDialog.pendingPreset + "\" will stop the current recording and start a new bag with the new config."
            width: parent ? parent.width : Units.pt(360)
            wrapMode: Text.Wrap
        }
    }
}
