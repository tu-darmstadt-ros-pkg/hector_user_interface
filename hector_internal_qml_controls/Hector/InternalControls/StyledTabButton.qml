import QtQuick
import QtQuick.Controls.Basic
import Hector.Utils
import Hector.Style

TabButton {
    id: control

    property var buttonStyle: Style.buttonStyle(style)
    property var style: Style.base

    font: Style.button.font
    hoverEnabled: true

    background: Rectangle {
        color: Style.handleMouseStates(control, control.buttonStyle.color, Style.background.content)
        implicitHeight: Style.button.defaultHeight
        implicitWidth: Units.pt(50)
        opacity: enabled ? 1 : 0.3
        visible: !control.flat && !control.checked
    }
    contentItem: Text {
        color: control.flat ? (control.checkable ? (control.checked ? control.buttonStyle.checkedColor : control.buttonStyle.uncheckedColor) : control.buttonStyle.color) : (control.checked ? Style.getTextColor(Style.background.content) : Style.getTextColor(control.background.color))
        elide: Text.ElideRight
        font: control.font
        horizontalAlignment: Text.AlignHCenter
        opacity: enabled ? 1 : 0.3
        text: control.text
        verticalAlignment: Text.AlignVCenter
    }
}
