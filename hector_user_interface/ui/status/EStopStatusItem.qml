import QtQuick 2.3
import QtQuick.Controls 2.2
import QtQuick.Layouts 1.1
import Hector.Controls 1.0
import Hector.Style 1.0

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
