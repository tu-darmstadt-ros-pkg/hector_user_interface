import QtQuick 2.3
import QtQuick.Controls 2.2
import QtQuick.Layouts 1.1
import Hector.Controls 1.0
import Hector.Style 1.0
import Hector.Utils 1.0

Rectangle {
    id: control

    property bool dangerous: false
    property real horizontalPadding: Units.pt(8)
    property alias icon: iconText.text
    property alias unit: unitText.text
    property alias value: valueText.text
    property real verticalPadding: Units.pt(6)
    property bool warn: false

    clip: true
    color: Style.background.content
    implicitHeight: mainLayout.implicitHeight + 2 * verticalPadding
    implicitWidth: mainLayout.implicitWidth + 2 * horizontalPadding
    radius: 0.25 * height

    border {
        color: iconBackground.color
        width: dangerous || warn ? Units.pt(2) : 0
    }
    RowLayout {
        id: mainLayout
        anchors.fill: parent
        spacing: 0

        Rectangle {
            id: iconBackground
            Layout.fillHeight: true
            color: dangerous ? Style.colors.status.error : warn ? Style.colors.status.warn : Style.colors.status.ok
            radius: control.radius
            width: Units.pt(20)

            Rectangle {
                anchors.bottom: parent.bottom
                anchors.right: parent.right
                anchors.top: parent.top
                color: parent.color
                width: control.radius
            }
            Text {
                id: iconText
                anchors.centerIn: parent
                color: Style.getTextColor(iconBackground.color)
                font.family: Style.iconFontFamily
                font.pointSize: 20
            }
        }
        Text {
            id: valueText
        }
        Text {
            id: unitText
            font.pointSize: 8
            visible: text.length > 0
        }
    }
}
