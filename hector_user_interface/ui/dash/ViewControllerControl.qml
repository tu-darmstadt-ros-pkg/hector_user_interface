import QtQuick 2.3
import QtQuick.Controls.Basic 2.1
import Hector.Controls 1.0
import Hector.InternalControls 1.0
import Hector.MultiRobot 1.0
import Hector.Style 1.0
import Hector.Utils 1.0
import Ros2 1.0

Item {
    id: root

    property string robotFrame
    property var style

    QtObject {
        id: d

        property real horizontalMargin: root.width / 2 - 25 * scale
        property real scale: Math.min(root.width / 66, root.height / 72)
        property real verticalMargin: root.height / 2 - 30 * scale

        onHorizontalMarginChanged: robotCanvas.requestPaint()
        onScaleChanged: robotCanvas.requestPaint()
        onVerticalMarginChanged: robotCanvas.requestPaint()
    }
    Canvas {
        id: robotCanvas
        anchors.fill: parent
        contextType: "2d"

        onPaint: {
            if (!context)
                // Wait for context to be valid
                return;
            context.save();
            var scale = d.scale;
            // Center and scale to fill
            context.translate(d.horizontalMargin, d.verticalMargin);
            context.scale(scale, scale);

            // Draw robot
            context.fillStyle = Qt.rgba(0.69, 0.69, 0.69, 1);
            context.fillRect(10, 3, 30, 54);
            // Tracks
            context.fillStyle = Qt.rgba(0, 0, 0, 1);
            context.path = "m 2,0 h 11 c 1.108,0 2,0.892 2,2 v 56 c 0,1.108 -0.892,2 -2,2 H 2 C 0.892,60 0,59.108 0,58 V 2 C 0,0.892 0.892,0 2,0 Z";
            context.fill();
            context.translate(35, 0);
            context.path = "m 2,0 h 11 c 1.108,0 2,0.892 2,2 v 56 c 0,1.108 -0.892,2 -2,2 H 2 C 0.892,60 0,59.108 0,58 V 2 C 0,0.892 0.892,0 2,0 Z";
            context.fill();
            context.restore();
        }
    }
    Text {
        anchors.centerIn: parent
        fontSizeMode: Text.Fit
        height: 20 * d.scale
        horizontalAlignment: Text.AlignHCenter
        minimumPointSize: 6
        text: Style.icons.viewController
        width: 20 * d.scale

        font {
            family: Style.iconFontFamily
            pointSize: 100
        }
    }

    // Lock
    StyledRoundButton {
        anchors.bottom: parent.bottom
        anchors.bottomMargin: d.verticalMargin - 8 * d.scale
        anchors.right: parent.right
        anchors.rightMargin: Math.max(d.horizontalMargin - 24 * d.scale, 0)
        checkable: true
        checked: OcsManager.trackedFrame == root.robotFrame
        flat: true
        height: 24 * d.scale
        padding: 0
        style: root.style
        text: checked ? Style.icons.lockClosed : Style.icons.lockOpen
        width: 24 * d.scale

        // Click toggle drops the binding; restore it so tracking stopped elsewhere still updates the icon.
        onClicked: {
            const track = checked;
            checked = Qt.binding(() => OcsManager.trackedFrame == root.robotFrame);
            OcsManager.trackFrame(track ? root.robotFrame : "");
        }

        font {
            family: Style.iconFontFamily
            pixelSize: 18 * d.scale
        }
    }

    // 2D / 3D Mode
    StyledRoundButton {
        anchors.bottom: parent.bottom
        anchors.bottomMargin: d.verticalMargin - 8 * d.scale
        anchors.left: parent.left
        anchors.leftMargin: Math.max(d.horizontalMargin - 28 * d.scale, 0)
        checkable: true
        checked: OcsManager.viewMode == "2D"
        flat: true
        height: 24 * d.scale
        padding: 0
        style: root.style
        text: checked ? "3D" : "2D"
        width: 24 * d.scale

        // See lock button: keep binding so a mode change made in rviz (Ctrl+D) is shown.
        onClicked: {
            const mode = checked ? "2D" : "3D";
            checked = Qt.binding(() => OcsManager.viewMode == "2D");
            OcsManager.setViewMode(mode);
        }

        font {
            letterSpacing: -2 * d.scale
            pixelSize: 18 * d.scale
            weight: Font.Bold
        }
    }

    // View Left
    StyledRoundButton {
        anchors.left: parent.left
        anchors.leftMargin: d.horizontalMargin - 8 * d.scale
        anchors.verticalCenter: parent.verticalCenter
        height: 24 * d.scale
        padding: 0
        style: root.style
        text: Style.icons.viewControllerLeft
        visible: OcsManager.viewMode == "3D"
        width: 24 * d.scale

        onClicked: OcsManager.moveCamera(0, 4, 4, root.robotFrame)

        font {
            family: Style.iconFontFamily
            pixelSize: 18 * d.scale
        }
    }

    // View Right
    StyledRoundButton {
        anchors.right: parent.right
        anchors.rightMargin: d.horizontalMargin - 8 * d.scale
        anchors.verticalCenter: parent.verticalCenter
        height: 24 * d.scale
        padding: 0
        style: root.style
        text: Style.icons.viewControllerRight
        visible: OcsManager.viewMode == "3D"
        width: 24 * d.scale

        onClicked: OcsManager.moveCamera(0, -4, 4, root.robotFrame)

        font {
            family: Style.iconFontFamily
            pixelSize: 18 * d.scale
        }
    }

    // View Front
    StyledRoundButton {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: d.verticalMargin - 6 * d.scale
        height: 24 * d.scale
        padding: 0
        style: root.style
        text: Style.icons.viewControllerFront
        visible: OcsManager.viewMode == "3D"
        width: 24 * d.scale

        onClicked: OcsManager.moveCamera(4, 0, 4, root.robotFrame)

        font {
            family: Style.iconFontFamily
            pixelSize: 18 * d.scale
        }
    }

    // View Back
    StyledRoundButton {
        anchors.bottom: parent.bottom
        anchors.bottomMargin: d.verticalMargin - 6 * d.scale
        anchors.horizontalCenter: parent.horizontalCenter
        height: 24 * d.scale
        padding: 0
        style: root.style
        text: Style.icons.viewControllerBack
        visible: OcsManager.viewMode == "3D"
        width: 24 * d.scale

        onClicked: OcsManager.moveCamera(-4, 0, 4, root.robotFrame)

        font {
            family: Style.iconFontFamily
            pixelSize: 18 * d.scale
        }
    }

    // View from top
    StyledRoundButton {
        anchors.centerIn: parent
        height: 24 * d.scale
        padding: 0
        style: root.style
        text: Style.icons.location
        visible: OcsManager.viewMode == "2D"
        width: 24 * d.scale

        onClicked: OcsManager.moveCamera2D(0, 0, root.robotFrame)

        font {
            family: Style.iconFontFamily
            pixelSize: 18 * d.scale
        }
    }
}
