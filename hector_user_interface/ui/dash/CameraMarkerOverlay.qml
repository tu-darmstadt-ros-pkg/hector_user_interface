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

    //! Selectable displays: { path, group, name, topic, classId, enabled }, ungrouped ones last.
    readonly property var availableDisplays: {
        settingsDialog.visible; // Topics do not notify changes, refresh when the dialog opens.
        let grouped = [];
        let ungrouped = [];
        collectDisplays(rviz.displayManager.displays, [], true, grouped, ungrouped);
        return grouped.concat(ungrouped);
    }
    readonly property var camera: stream ? Array.from(CameraServer.cameras).find(camera => camera.server.robot === stream.robot && camera.cameraId === stream.cameraId) || null : null
    readonly property var detectionTopics: d.selection("detections", detections ? detections.topics.filter(topic => !stream || topic.startsWith("/" + stream.robot + "/")) : [])
    //! The shared DetectionSubscriptions.
    property var detections: null
    readonly property var info: cameraInfoSubscription.message
    //! The stored selection { displays, detections }. A missing entry selects all marker displays or the robot's detection topics.
    property var settings: ({})
    //! The CameraStream whose camera is used.
    property var stream: null

    //! Emitted when the user changes the selection.
    signal settingsEdited(var settings)

    function collectDisplays(displays, groups, enabled, grouped, ungrouped) {
        let names = {};
        for (const display of displays) {
            // Displays with the same name in one group are numbered from the second on.
            names[display.name] = (names[display.name] || 0) + 1;
            const path = groups.concat(names[display.name] > 1 ? display.name + "#" + names[display.name] : display.name);
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
        if (detections)
            detections.refresh();
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

    displays: d.selection("displays", availableDisplays.filter(display => d.markerClasses.includes(display.classId)).map(display => display.path))
    frameId: info ? info.header.frame_id : ""
    imageSize: info ? Qt.size(info.width, info.height) : Qt.size(0, 0)
    intrinsics: info ? Qt.vector4d(info.k.at(0), info.k.at(4), info.k.at(2), info.k.at(5)) : Qt.vector4d(0, 0, 0, 0)
    stamp: stream && stream.captureTime || 0

    QtObject {
        id: d

        readonly property var availableDetectionTopics: control.detections ? control.detections.topics : []
        readonly property string cameraInfoTopic: {
            if (control.camera && control.camera.cameraInfoTopic)
                return control.camera.cameraInfoTopic;
            const rosStream = control.camera && Array.from(control.camera.streams).find(cameraStream => cameraStream.transport === "ros2");
            return rosStream ? rosStream.uri.replace(/[^/]*$/, "camera_info") : "";
        }
        //! Detections older than this relative to the shown image are hidden.
        readonly property real detectionTimeout: 1
        readonly property var markerClasses: ["rviz_default_plugins/Marker", "rviz_default_plugins/MarkerArray", "rviz_default_plugins/InteractiveMarkers"]
        readonly property var overlayClasses: markerClasses.concat(["rviz_default_plugins/Path", "rviz_default_plugins/PointStamped", "rviz_default_plugins/Polygon", "rviz_default_plugins/Pose", "rviz_default_plugins/PoseArray"])
        readonly property real scaleX: control.imageSize.width > 0 ? control.width / control.imageSize.width : 0
        readonly property real scaleY: control.imageSize.height > 0 ? control.height / control.imageSize.height : 0
        //! The rotation of the camera view this overlay is drawn in, see CameraViewImpl.
        readonly property real viewRotation: control.parent ? control.parent.rotation : 0

        // A stored empty list is read back as null from the rviz config.
        function selection(key, defaults) {
            const value = control.settings[key];
            return value === undefined ? defaults : Array.from(value || []);
        }
    }
    // The camera_info is only fetched once and refreshed periodically to save bandwidth.
    Subscription {
        id: cameraInfoSubscription

        // Latched camera_infos, e.g., of image_projection, need a transient local subscription which
        // does not match volatile publishers with DDS. Hence, the durability of the publishers is used.
        property bool latched: {
            revision;
            return Ros2.getPublishersInfoByTopic(topic).some(info => info.qos.durability === DurabilityPolicy.TransientLocal);
        }
        property bool requested: true
        property int revision: 0

        enabled: control.visible && requested && topic !== ""
        messageType: "sensor_msgs/msg/CameraInfo"
        qos: latched ? Ros2.QoS().transient_local().reliable() : Ros2.QoS()
        topic: d.cameraInfoTopic

        onMessageChanged: requested = !message
    }
    // Checks the publishers again until a camera_info is received, as they may not be discovered yet.
    Timer {
        interval: cameraInfoSubscription.message ? 30000 : 1000
        repeat: true
        running: control.visible

        onTriggered: {
            cameraInfoSubscription.revision++;
            cameraInfoSubscription.requested = true;
        }
    }
    Repeater {
        model: control.visible && control.frameId !== "" && control.detections ? control.detectionTopics : []

        delegate: Item {
            id: detectionsItem

            // Without capture times of the shown image, detections are hidden if none were received for the timeout.
            property bool fresh: false
            readonly property var message: subscription ? subscription.message : null
            readonly property var subscription: control.detections.subscription(topic)
            readonly property string topic: modelData

            anchors.fill: parent
            visible: !!message && message.header.frame_id === control.frameId && (control.stamp ? Math.abs(control.stamp - message.header.stamp.seconds()) < d.detectionTimeout : fresh)

            Component.onCompleted: control.detections.acquire(topic)
            Component.onDestruction: {
                if (control.detections)
                    control.detections.release(topic);
            }
            onMessageChanged: {
                fresh = true;
                freshTimer.restart();
            }

            Timer {
                id: freshTimer

                interval: d.detectionTimeout * 1000

                onTriggered: detectionsItem.fresh = false
            }
            Repeater {
                model: detectionsItem.visible ? detectionsItem.message.detections.length : 0

                delegate: Item {
                    id: detectionItem

                    readonly property var box: detection.bounding_box
                    readonly property var detection: detectionsItem.message.detections.at(index)
                    readonly property real hue: ((detection.id * 0.618) % 1 + 1) % 1

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
                    // The box as seen on screen, labeled on its top edge or inside if there is no space above.
                    Item {
                        readonly property bool sideways: d.viewRotation % 180 !== 0
                        readonly property real spaceAbove: [boxRectangle.y, boxRectangle.x, control.height - boxRectangle.y - boxRectangle.height, control.width - boxRectangle.x - boxRectangle.width][(d.viewRotation / 90 % 4 + 4) % 4]

                        anchors.centerIn: boxRectangle
                        height: sideways ? boxRectangle.width : boxRectangle.height
                        rotation: -d.viewRotation
                        visible: boxRectangle.visible
                        width: sideways ? boxRectangle.height : boxRectangle.width

                        Pill {
                            color: boxRectangle.border.color
                            font: Style.fonts.tiny
                            horizontalPadding: Units.pt(4)
                            text: detectionItem.detection.label + " " + Math.round(detectionItem.detection.score * 100) + "%"
                            // By perceived brightness, the hsl lightness of all detection colors is the same.
                            textColor: 0.299 * color.r + 0.587 * color.g + 0.114 * color.b > 0.55 ? "black" : "white"
                            verticalPadding: Units.pt(1)
                            y: parent.spaceAbove >= height ? -height : 0
                        }
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
                    model: Array.from(new Set(d.availableDetectionTopics.concat(control.detectionTopics)))
                    spacing: Units.pt(2)

                    delegate: CameraOverlayListItem {
                        active: d.availableDetectionTopics.includes(modelData)
                        checked: control.detectionTopics.includes(modelData)
                        inactiveToolTip: "The topic does not exist (anymore)."
                        name: modelData
                        width: ListView.view.width

                        onToggled: control.setSelected("detections", modelData, !checked)
                    }
                    footer: Text {
                        height: ListView.view.count === 0 ? implicitHeight + Units.pt(8) : 0
                        horizontalAlignment: Text.AlignHCenter
                        opacity: 0.6
                        text: "No detection topics found."
                        verticalAlignment: Text.AlignVCenter
                        visible: ListView.view.count === 0
                        width: ListView.view.width
                    }
                }
            }
        }
    }
}
