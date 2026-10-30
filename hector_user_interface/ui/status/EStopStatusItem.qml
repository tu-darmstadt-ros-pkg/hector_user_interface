import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import Hector.Controls
import Hector.Style

Item {
    id: control

    property string name
    property bool value

    implicitHeight: mainLayout.implicitHeight
    implicitWidth: mainLayout.implicitWidth

    RowLayout {
        id: mainLayout
        anchors.fill: parent

        Text {
            Layout.fillWidth: true
            text: control.name
        }
        Pill {
            color: value ? Style.safe.primary.color : Style.background.container
            text: value ? "On" : "Off"
            textColor: Style.getTextColor(color)
        }
    }
}
