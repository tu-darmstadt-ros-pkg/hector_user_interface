import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import Hector.Controls
import Hector.Style
import Hector.Utils

//! A checkable entry of the camera overlay settings.
Rectangle {
    id: control

    property bool active: true
    property bool checked: false
    //! Shown while not active.
    property string inactiveToolTip
    property alias name: nameText.text
    property alias pill: pill.text
    property alias subtitle: subtitleText.text

    signal toggled

    color: Style.background.container
    implicitHeight: itemLayout.implicitHeight
    opacity: active ? 1 : 0.4

    RowLayout {
        id: itemLayout

        anchors.fill: parent

        CheckBox {
            checked: control.checked
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            Text {
                id: nameText

                Layout.fillWidth: true
                elide: Text.ElideRight
            }
            Text {
                id: subtitleText

                Layout.fillWidth: true
                elide: Text.ElideMiddle
                font: Style.fonts.small
                opacity: 0.6
                visible: text !== ""
            }
        }
        Pill {
            id: pill

            Layout.rightMargin: Units.pt(8)
            color: Style.background.content
            font: Style.fonts.tiny
            visible: text !== ""
        }
    }
    SimpleToolTip {
        text: control.inactiveToolTip
        visible: !control.active && text !== ""
    }
    MouseArea {
        anchors.fill: parent

        onClicked: control.toggled()
    }
}
