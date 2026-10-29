import QtQuick 2.3
import QtQuick.Controls 2.2
import QtQuick.Layouts 1.1
import Hector.Icons 1.0
import Hector.MultiRobot 1.0
import Hector.Style 1.0
import Hector.Utils 1.0

// Left-side multi-robot panel: a header with the robot count above a scrollable list of tiles for
// all discovered robots, pinned ones first. Clicking a tile switches the active robot, its star
// toggles the pin. Clicking the header collapses the list to the left, leaving the header as a
// compact tab. Reads discovered robots directly from RobotManager.robots; pins persist in the rviz
// config.
Item {
    id: root

    //! Whether the list is slid out of view to the left, leaving only the header tab.
    property bool collapsed: false

    //! Pinned robot ids in pin order, persisted in the rviz config.
    readonly property var pinnedIds: rviz.config.pinnedRobots || []

    //! All discovered robots: pinned ones in pin order, then the rest in discovery order.
    //! Undiscovered pinned ids are dropped.
    readonly property var sortedRobots: pinnedIds.map(id => RobotManager.robots.find(r => r.robot_id === id)).filter(Boolean).concat(RobotManager.robots.filter(r => pinnedIds.indexOf(r.robot_id) < 0))

    function togglePin(id) {
        let config = rviz.config;
        let ids = root.pinnedIds.slice();
        let index = ids.indexOf(id);
        if (index >= 0)
            ids.splice(index, 1);
        else
            ids.push(id);
        config.pinnedRobots = ids;
        rviz.config = config;
    }

    width: Units.pt(240)

    Rectangle {
        id: pane
        color: Style.background.container
        // Fits the tiles, bounded so it never grows past the available channel.
        height: Math.min(parent.height - y, list.contentHeight + 2 * list.anchors.margins)
        // Hidden once fully slid out so the tiles (and their camera feeds) are destroyed.
        visible: x > -width
        width: parent.width
        x: root.collapsed ? -width : 0
        y: header.height

        Behavior on x  {
            NumberAnimation {
                duration: 150
                easing.type: Easing.OutCubic
            }
        }

        // Catches all mouse events the tiles didn't handle (including wheel events at the end of the
        // list) to prevent them from going to rviz.
        MouseArea {
            acceptedButtons: Qt.AllButtons
            anchors.fill: parent

            onWheel: wheel.accepted = true
        }
        ListView {
            id: list
            anchors.fill: parent
            anchors.margins: Units.pt(4)
            clip: true
            interactive: contentHeight > height
            model: pane.visible ? root.sortedRobots : []
            spacing: Units.pt(4)

            ScrollBar.vertical: ScrollBar {
            }
            delegate: RobotTile {
                pinned: root.pinnedIds.indexOf(modelData.robot_id) >= 0
                robot: modelData
                width: list.width

                onClicked: RobotManager.setActiveRobot(modelData)
                onPinToggled: root.togglePin(modelData.robot_id)
            }
        }
    }

    // Declared after the pane so the list slides out underneath it.
    Rectangle {
        id: header
        color: headerMouseArea.containsMouse ? Qt.darker(Style.background.container, 1.08) : Style.background.container
        height: Units.pt(24)
        width: root.collapsed ? headerLayout.implicitWidth + headerLayout.anchors.leftMargin + headerLayout.anchors.rightMargin : root.width

        Behavior on width  {
            NumberAnimation {
                duration: 150
                easing.type: Easing.OutCubic
            }
        }

        RowLayout {
            id: headerLayout
            anchors.fill: parent
            anchors.leftMargin: Units.pt(6)
            anchors.rightMargin: Units.pt(4)
            spacing: Units.pt(4)

            Text {
                color: Style.getTextColor(header.color)
                font.family: Style.iconFontFamily
                font.pixelSize: Units.pt(16)
                text: Style.icons.robot
            }
            Text {
                Layout.fillWidth: true
                color: Style.getTextColor(header.color)
                font: Style.fonts.subHeader
                text: RobotManager.robots.length + " robots"
            }
            Text {
                color: Style.getTextColor(header.color)
                font.family: HectorIcons.fontFamily
                font.pixelSize: Units.pt(18)
                text: root.collapsed ? HectorIcons.chevronRight : HectorIcons.chevronLeft
            }
        }
        MouseArea {
            id: headerMouseArea
            anchors.fill: parent
            hoverEnabled: true

            onClicked: root.collapsed = !root.collapsed
            onWheel: wheel.accepted = true
        }
    }
}
