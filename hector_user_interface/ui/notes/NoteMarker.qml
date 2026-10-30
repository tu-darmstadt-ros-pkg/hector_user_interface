import QtQuick
import Hector.Utils

// One note icon anchored to the note's 3D point. Hidden while note is null.
Item {
    id: marker

    property color color
    property var note: null
    property bool positionValid: false
    property var tool
    property var tracker: null

    signal clicked

    function refresh() {
        if (!marker.tool || !marker.note)
            return;
        var s = marker.tool.scenePosition(marker.note);
        marker.positionValid = s.valid;
        if (!s.valid)
            return;
        if (marker.tracker)
            marker.tracker.point = s.position;
        else
            marker.tracker = rviz.createPositionTracker(s.position.x, s.position.y, s.position.z);
    }

    height: width
    // If the transform is lost, keep the last position but hide instead of jumping to a sentinel.
    visible: !!marker.note && marker.positionValid && marker.tracker && marker.tracker.visible
    width: Units.pt(24)
    x: marker.tracker ? marker.tracker.position.x - width / 2 : 0
    y: marker.tracker ? marker.tracker.position.y - height / 2 : 0

    Component.onCompleted: refresh()
    // The tracker is parented to the overlay and keeps its camera listener until destroyed.
    // QML hides deleteLater; destroy() works as the tracker has no explicit CppOwnership.
    Component.onDestruction: if (marker.tracker)
        marker.tracker.destroy()
    onNoteChanged: refresh()

    Connections {
        function onNoteTransformsChanged() {
            marker.refresh();
        }

        target: marker.tool
    }
    NoteIcon {
        anchors.fill: parent
        backgroundColor: marker.color
        iconName: marker.note && marker.note.icon || ""
    }
    MouseArea {
        anchors.fill: parent

        onClicked: marker.clicked()
    }
}
