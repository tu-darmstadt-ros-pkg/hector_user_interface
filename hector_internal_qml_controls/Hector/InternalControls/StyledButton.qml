import QtQuick 2.6
import QtQuick.Controls 2.2
import Hector.Utils 1.0
import Hector.Style 1.0

Button {
    id: control

    property var buttonStyle: Style.buttonStyle(style)
    property real radius: 0
    property var style: Style.base

    font: Style.button.font
    hoverEnabled: true
    padding: Units.pt(2)

    background: Rectangle {
        color: Style.handleMouseStates(control, control.checkable ? control.buttonStyle.uncheckedColor : control.buttonStyle.color, control.buttonStyle.checkedColor)
        implicitHeight: Style.button.defaultHeight
        implicitWidth: Units.pt(50)
        opacity: enabled ? 1 : 0.3
        radius: control.radius
        visible: !control.flat
    }
    contentItem: Text {
        bottomPadding: control.bottomPadding
        color: control.flat ? (control.checkable ? (control.checked ? control.buttonStyle.checkedColor : control.buttonStyle.uncheckedColor) : control.buttonStyle.color) : Style.getTextColor(control.background.color)
        elide: Text.ElideRight
        font: control.font
        horizontalAlignment: Text.AlignHCenter
        leftPadding: control.leftPadding
        opacity: enabled ? 1 : 0.3
        rightPadding: control.rightPadding
        text: control.text
        topPadding: control.topPadding
        verticalAlignment: Text.AlignVCenter
    }
}
