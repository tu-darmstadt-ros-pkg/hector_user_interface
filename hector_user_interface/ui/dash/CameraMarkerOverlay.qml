import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import QtQuick.Templates as T
import Ros2
import Ros2.CameraServer
import Hector.Controls
import Hector.RvizOverlay
import Hector.Style
import Hector.Utils

//! Renders the rviz markers from the perspective of the camera of the given CameraStream.
//! The camera_info topic is taken from the camera announcement or, if not announced, expected next
//! to the image topic of one of the camera's ros2 streams.
CameraOverlay {
    id: control

    //! Selectable displays: { path, group, name, topic, classId, enabled }, ungrouped ones last.
    readonly property var availableDisplays: {
        settingsDialog.visible; // Topics do not notify changes, refresh when the dialog opens.
        let grouped = [];
        let ungrouped = [];
        collectDisplays(rviz.displayManager.displays, [], true, grouped, ungrouped);
        return grouped.concat(ungrouped);
    }
    readonly property var camera: stream ? Array.from(CameraServer.cameras).find(camera => camera.server.robot === stream.robot && camera.cameraId === stream.cameraId) || null : null
    readonly property var info: cameraInfoSubscription.message
    //! The paths of the selected displays. Undefined selects all marker displays.
    property var selectedDisplays: undefined
    //! The CameraStream whose camera is used.
    property var stream: null

    //! Emitted when the user changes the selected displays.
    signal selectionEdited(var displays)

    function collectDisplays(displays, groups, enabled, grouped, ungrouped) {
        for (const display of displays) {
            const path = groups.concat(display.name);
            const displayEnabled = enabled && display.enabled;
            if (display.isGroup)
                collectDisplays(display.displays, path, displayEnabled, grouped, ungrouped);
            else if (d.overlayClasses.includes(display.classId))
                (groups.length > 0 ? grouped : ungrouped).push({
                    "path": path.join("/"),
                    "group": groups.join(" / "),
                    "name": display.name,
                    "topic": display.getPropertyValue("Topic") || "",
                    "classId": display.classId,
                    "enabled": displayEnabled
                });
        }
    }
    function openSettings() {
        settingsDialog.open();
    }
    function setSelected(path, selected) {
        let displays = Array.from(control.displays).filter(p => p !== path);
        if (selected)
            displays.push(path);
        control.selectionEdited(displays);
    }

    displays: selectedDisplays !== undefined ? selectedDisplays : availableDisplays.filter(display => d.markerClasses.includes(display.classId)).map(display => display.path)
    frameId: info ? info.header.frame_id : ""
    imageSize: info ? Qt.size(info.width, info.height) : Qt.size(0, 0)
    intrinsics: info ? Qt.vector4d(info.k.at(0), info.k.at(4), info.k.at(2), info.k.at(5)) : Qt.vector4d(0, 0, 0, 0)
    stamp: stream && stream.captureTime || 0

    QtObject {
        id: d

        readonly property string cameraInfoTopic: {
            if (control.camera && control.camera.cameraInfoTopic)
                return control.camera.cameraInfoTopic;
            const rosStream = control.camera && Array.from(control.camera.streams).find(cameraStream => cameraStream.transport === "ros2");
            return rosStream ? rosStream.uri.replace(/[^/]*$/, "camera_info") : "";
        }
        readonly property var markerClasses: ["rviz_default_plugins/Marker", "rviz_default_plugins/MarkerArray", "rviz_default_plugins/InteractiveMarkers"]
        readonly property var overlayClasses: markerClasses.concat(["rviz_default_plugins/Path", "rviz_default_plugins/PointStamped", "rviz_default_plugins/Polygon", "rviz_default_plugins/Pose", "rviz_default_plugins/PoseArray"])
    }
    Subscription {
        id: cameraInfoSubscription

        enabled: control.visible && topic !== ""
        messageType: "sensor_msgs/msg/CameraInfo"
        throttleRate: 1
        topic: d.cameraInfoTopic
    }
    Dialog {
        id: settingsDialog

        modal: true
        parent: T.Overlay.overlay
        title: "Camera Markers" + (control.camera ? " – " + control.camera.name : "")
        width: Math.min(parent.width * 0.6, Units.pt(320))
        x: (parent.width - width) / 2
        y: (parent.height - height) / 2

        ListView {
            anchors.fill: parent
            clip: true
            implicitHeight: Math.min(contentHeight, Units.pt(240))
            model: control.availableDisplays
            spacing: Units.pt(2)

            delegate: Column {
                id: displayItem

                readonly property bool selected: control.displays.includes(modelData.path)

                spacing: Units.pt(2)
                width: ListView.view.width

                SectionHeader {
                    height: implicitHeight + Units.pt(8)
                    text: modelData.group
                    visible: modelData.group !== "" && (index === 0 || control.availableDisplays[index - 1].group !== modelData.group)
                    width: parent.width
                }
                Rectangle {
                    color: Style.background.container
                    implicitHeight: itemLayout.implicitHeight
                    opacity: modelData.enabled ? 1 : 0.4
                    width: parent.width

                    RowLayout {
                        id: itemLayout

                        anchors.fill: parent

                        CheckBox {
                            checked: displayItem.selected
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            Text {
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                                text: modelData.name
                            }
                            Text {
                                Layout.fillWidth: true
                                elide: Text.ElideMiddle
                                font: Style.fonts.small
                                opacity: 0.6
                                text: modelData.topic
                                visible: text !== ""
                            }
                        }
                        Pill {
                            Layout.rightMargin: Units.pt(8)
                            color: Style.background.content
                            font: Style.fonts.tiny
                            text: modelData.classId.split("/").pop()
                        }
                    }
                    SimpleToolTip {
                        text: "Enable the display in rviz to show it."
                        visible: !modelData.enabled
                    }
                    MouseArea {
                        anchors.fill: parent

                        onClicked: control.setSelected(modelData.path, !displayItem.selected)
                    }
                }
            }
        }
    }
}
