import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import QtQuick.Shapes
import QtQuick.Templates as T
import Ros2
import Ros2.CameraServer
import Hector.Controls
import Hector.RvizOverlay
import Hector.Style
import Hector.Utils

//! Renders the rviz markers and the 2D detections of the camera of the given CameraStream on top of its image.
//! The camera_info topic is taken from the camera announcement or, if not announced, expected next
//! to the image topic of one of the camera's ros2 streams.
//! Detections are only drawn if their frame matches the camera_info frame.
CameraOverlay {
    id: control

    readonly property var availableDetectionTopics: {
        settingsDialog.visible;
        d.topicRevision;
        return Ros2.queryTopics(d.detectionType).sort();
    }
    //! Selectable displays: { path, group, name, topic, classId, enabled }, ungrouped ones last.
    readonly property var availableDisplays: {
        settingsDialog.visible; // Topics do not notify changes, refresh when the dialog opens.
        let grouped = [];
        let ungrouped = [];
        collectDisplays(rviz.displayManager.displays, [], true, grouped, ungrouped);
        return grouped.concat(ungrouped);
    }
    readonly property var camera: stream ? Array.from(CameraServer.cameras).find(camera => camera.server.robot === stream.robot && camera.cameraId === stream.cameraId) || null : null
    readonly property var detectionTopics: settings.detections !== undefined ? settings.detections : availableDetectionTopics
    readonly property var info: cameraInfoSubscription.message
    //! The stored selection { displays, detections }. A missing entry selects all marker displays or detection topics.
    property var settings: ({})
    //! The CameraStream whose camera is used.
    property var stream: null

    //! Emitted when the user changes the selection.
    signal settingsEdited(var settings)

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
    function setSelected(key, value, selected) {
        let values = Array.from(key === "displays" ? control.displays : control.detectionTopics).filter(v => v !== value);
        if (selected)
            values.push(value);
        let settings = Object.assign({}, control.settings);
        settings[key] = values;
        control.settingsEdited(settings);
    }

    displays: settings.displays !== undefined ? settings.displays : availableDisplays.filter(display => d.markerClasses.includes(display.classId)).map(display => display.path)
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
        //! Detections older than this relative to the shown image are hidden.
        readonly property real detectionTimeout: 1
        readonly property string detectionType: "hector_perception_msgs/msg/ObjectDetection2DArray"
        readonly property var markerClasses: ["rviz_default_plugins/Marker", "rviz_default_plugins/MarkerArray", "rviz_default_plugins/InteractiveMarkers"]
        readonly property var overlayClasses: markerClasses.concat(["rviz_default_plugins/Path", "rviz_default_plugins/PointStamped", "rviz_default_plugins/Polygon", "rviz_default_plugins/Pose", "rviz_default_plugins/PoseArray"])
        readonly property real scaleX: control.imageSize.width > 0 ? control.width / control.imageSize.width : 0
        readonly property real scaleY: control.imageSize.height > 0 ? control.height / control.imageSize.height : 0
        property int topicRevision: 0
    }
    Subscription {
        id: cameraInfoSubscription

        enabled: control.visible && topic !== ""
        messageType: "sensor_msgs/msg/CameraInfo"
        throttleRate: 1
        topic: d.cameraInfoTopic
    }
    Timer {
        interval: 5000
        repeat: true
        running: control.visible && control.settings.detections === undefined

        onTriggered: d.topicRevision++
    }
    Repeater {
        model: control.visible && control.frameId !== "" ? control.detectionTopics : []

        delegate: Item {
            id: detectionsItem

            readonly property var message: detectionSubscription.message

            anchors.fill: parent
            visible: !!message && message.header.frame_id === control.frameId && (!control.stamp || control.stamp - message.header.stamp.seconds() < d.detectionTimeout)

            Subscription {
                id: detectionSubscription

                messageType: d.detectionType
                topic: modelData
            }
            Repeater {
                model: detectionsItem.visible ? detectionsItem.message.detections.length : 0

                delegate: Item {
                    id: detectionItem

                    readonly property var box: detection.bounding_box
                    readonly property var detection: detectionsItem.message.detections.at(index)
                    readonly property real hue: (detection.id * 0.618) % 1

                    Shape {
                        visible: detectionItem.detection.mask.points.length > 2

                        transform: Scale {
                            xScale: d.scaleX
                            yScale: d.scaleY
                        }

                        ShapePath {
                            fillColor: Qt.hsla(detectionItem.hue, 0.9, 0.5, 0.35)
                            strokeColor: "transparent"

                            PathPolyline {
                                path: detectionItem.detection.mask.points.toArray().map(point => Qt.point(point.x, point.y))
                            }
                        }
                    }
                    Rectangle {
                        id: boxRectangle

                        border.color: Qt.hsla(detectionItem.hue, 0.9, 0.5, 1)
                        border.width: Units.pt(1)
                        color: "transparent"
                        height: (detectionItem.box.bottom - detectionItem.box.top) * d.scaleY
                        visible: width > 0 && height > 0
                        width: (detectionItem.box.right - detectionItem.box.left) * d.scaleX
                        x: detectionItem.box.left * d.scaleX
                        y: detectionItem.box.top * d.scaleY
                    }
                    Pill {
                        color: boxRectangle.border.color
                        font: Style.fonts.tiny
                        horizontalPadding: Units.pt(4)
                        text: detectionItem.detection.label + " " + Math.round(detectionItem.detection.score * 100) + "%"
                        textColor: Style.getTextColor(color)
                        verticalPadding: Units.pt(1)
                        x: boxRectangle.x
                        y: Math.max(0, boxRectangle.y - height)
                    }
                }
            }
        }
    }
    Dialog {
        id: settingsDialog

        modal: true
        parent: T.Overlay.overlay
        title: "Camera Overlay" + (control.camera ? " – " + control.camera.name : "")
        width: Math.min(parent.width * 0.6, Units.pt(320))
        x: (parent.width - width) / 2
        y: (parent.height - height) / 2

        ColumnLayout {
            anchors.fill: parent

            TabBar {
                id: tabBar

                Layout.fillWidth: true
                spacing: 0

                Repeater {
                    model: ["3D Markers", "2D Detections"]

                    TabButton {
                        id: tabButton

                        font: Style.button.font
                        hoverEnabled: true
                        text: modelData

                        background: Rectangle {
                            color: Style.handleMouseStates(tabButton, Style.background.container, Style.buttonStyle(Style.activeStyle).color)
                            implicitHeight: Style.button.defaultHeight
                        }
                        contentItem: Text {
                            color: Style.getTextColor(tabButton.background.color)
                            elide: Text.ElideRight
                            font: tabButton.font
                            horizontalAlignment: Text.AlignHCenter
                            text: tabButton.text
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                }
            }
            StackLayout {
                Layout.fillWidth: true
                currentIndex: tabBar.currentIndex

                ListView {
                    clip: true
                    implicitHeight: Math.min(contentHeight, Units.pt(240))
                    model: control.availableDisplays
                    spacing: Units.pt(2)

                    delegate: Column {
                        spacing: Units.pt(2)
                        width: ListView.view.width

                        SectionHeader {
                            height: implicitHeight + Units.pt(8)
                            text: modelData.group
                            visible: modelData.group !== "" && (index === 0 || control.availableDisplays[index - 1].group !== modelData.group)
                            width: parent.width
                        }
                        CameraOverlayListItem {
                            active: modelData.enabled
                            checked: control.displays.includes(modelData.path)
                            inactiveToolTip: "Enable the display in rviz to show it."
                            name: modelData.name
                            pill: modelData.classId.split("/").pop()
                            subtitle: modelData.topic
                            width: parent.width

                            onToggled: control.setSelected("displays", modelData.path, !checked)
                        }
                    }
                }
                ListView {
                    clip: true
                    implicitHeight: Math.min(Math.max(contentHeight, Units.pt(24)), Units.pt(240))
                    model: Array.from(new Set(control.availableDetectionTopics.concat(control.detectionTopics)))
                    spacing: Units.pt(2)

                    delegate: CameraOverlayListItem {
                        active: control.availableDetectionTopics.includes(modelData)
                        checked: control.detectionTopics.includes(modelData)
                        inactiveToolTip: "No publisher on this topic."
                        name: modelData
                        width: ListView.view.width

                        onToggled: control.setSelected("detections", modelData, !checked)
                    }

                    Text {
                        anchors.centerIn: parent
                        opacity: 0.6
                        text: "No detection topics found."
                        visible: parent.count === 0
                    }
                }
            }
        }
    }
}
