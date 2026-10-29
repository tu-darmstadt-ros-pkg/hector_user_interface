import QtQuick 2.3
import QtQuick.Controls 2.1
import Hector.Utils 1.0
import Hector.Style 1.0

RoundButton {
    id: control

    property var buttonStyle: Style.buttonStyle(style)
    property var style: Style.base

    font: Style.button.font
    hoverEnabled: true

    background: Rectangle {
        color: Style.handleMouseStates(control, control.checkable ? control.buttonStyle.uncheckedColor : control.buttonStyle.color, control.buttonStyle.checkedColor)
        implicitHeight: Units.pt(20)
        implicitWidth: Units.pt(20)
        opacity: enabled ? 1 : 0.3
        radius: control.radius
        visible: !control.flat
    }
    contentItem: Text {
        color: control.flat ? Style.handleMouseStates(control, control.checkable ? (control.checked ? control.buttonStyle.checkedColor : control.buttonStyle.uncheckedColor) : control.buttonStyle.color) : Style.getTextColor(control.background.color)
        elide: Text.ElideRight
        font: control.font
        horizontalAlignment: Text.AlignHCenter
        opacity: enabled ? 1 : 0.3
        text: control.text
        verticalAlignment: Text.AlignVCenter
    }
}
