import QtQuick 2.8
import QtQuick.Controls 2.2
import Hector.InternalControls 1.0
import Hector.Controls 1.0
import Hector.Utils 1.0

Item {
    id: root

    property bool dismissed: false

    anchors.fill: parent

    // Full overlay shown while loading and not dismissed.
    Item {
        id: fullContent
        anchors.fill: parent
        visible: !root.dismissed

        Rectangle {
            anchors.fill: parent
            color: "#3E3E3E"
        }
        Image {
            id: hectorLogo

            property real scale: Math.min(root.width / sourceSize.width, root.height / sourceSize.height) * 0.6

            anchors.centerIn: parent
            height: sourceSize.height * scale
            source: "../media/logo.svg"
            width: sourceSize.width * scale
        }
        StyledButton {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: hectorLogo.bottom
            anchors.topMargin: Units.pt(16)
            font.pointSize: 11
            padding: Units.pt(8)
            text: "Continue without robot"

            background: Rectangle {
                color: parent.hovered ? "#5A5A5A" : "#4A4A4A"
                radius: Units.pt(2)
            }
            contentItem: Text {
                color: "#FFD500"
                font: parent.font
                horizontalAlignment: Text.AlignHCenter
                text: parent.text
                verticalAlignment: Text.AlignVCenter
            }

            onClicked: root.dismissed = true
        }
        Progress {
            id: progressBar
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            backgroundColor: "#3E3E3E"
            height: Units.pt(12)
            indefiniteColor: "#FFD500"
            width: parent.width
        }
        Text {
            anchors.bottom: progressBar.top
            anchors.bottomMargin: Units.pt(4)
            anchors.left: progressBar.left
            anchors.leftMargin: Units.pt(10)
            color: "#FFD500"
            font.pixelSize: Units.pt(20)
            text: "Waiting for robot..."
        }
    }

    // Compact loading indicator shown after dismissing. Click to restore the
    // full splash screen.
    Rectangle {
        id: miniIndicator
        anchors.bottom: parent.bottom
        anchors.margins: Units.pt(8)
        anchors.right: parent.right
        border.color: "#FFD500"
        border.width: 1
        color: "#3E3E3E"
        height: miniRow.implicitHeight + Units.pt(8)
        radius: Units.pt(2)
        visible: root.dismissed
        width: miniRow.implicitWidth + Units.pt(16)

        Row {
            id: miniRow
            anchors.centerIn: parent
            spacing: Units.pt(8)

            Text {
                anchors.verticalCenter: parent.verticalCenter
                color: "#FFD500"
                font.pixelSize: Units.pt(14)
                text: "Waiting for robot..."
            }
            Progress {
                anchors.verticalCenter: parent.verticalCenter
                backgroundColor: "#3E3E3E"
                height: Units.pt(8)
                indefiniteColor: "#FFD500"
                width: Units.pt(80)
            }
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor

            onClicked: root.dismissed = false
        }
    }
}
