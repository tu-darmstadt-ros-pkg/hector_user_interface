import QtQuick 2.3
import QtQuick.Controls.Basic 2.2
import Hector.Controls 1.0
import Hector.Style 1.0
import Hector.Utils 1.0

//! Segmented three-state control for a visualization's visibility mode.
//! Does not write mode itself, the owner updates it in response to modeSelected.
Row {
    id: control

    //! A Robot.VisualizationMode value (0 off, 1 when active, 2 on).
    property int mode: 0
    property var style: Style.base

    signal modeSelected(int mode)

    Repeater {
        model: [{
                "value": 0,
                "icon": Style.icons.eyeOff,
                "tooltip": "Hidden"
            }, {
                "value": 1,
                "icon": Style.icons.eyeOutline,
                "tooltip": "Shown while robot is active"
            }, {
                "value": 2,
                "icon": Style.icons.eye,
                "tooltip": "Always shown"
            }]

        delegate: Button {
            id: button

            property var buttonStyle: Style.buttonStyle(control.style)

            autoExclusive: true
            checkable: true
            height: Units.pt(16)
            hoverEnabled: true
            width: Units.pt(16)

            background: Rectangle {
                color: Style.handleMouseStates(button, button.buttonStyle.uncheckedColor, button.buttonStyle.checkedColor)
                opacity: enabled ? 1 : 0.3
            }
            // Binding element so the click-toggle doesn't destroy the declarative binding.
            Binding on checked  {
                value: control.mode === modelData.value
            }
            contentItem: Text {
                color: Style.getTextColor(button.background.color)
                font.family: Style.iconFontFamily
                font.pointSize: 11
                horizontalAlignment: Text.AlignHCenter
                opacity: enabled ? 1 : 0.3
                text: modelData.icon
                verticalAlignment: Text.AlignVCenter
            }

            onClicked: control.modeSelected(modelData.value)

            SimpleToolTip {
                text: modelData.tooltip
            }
        }
    }
}
