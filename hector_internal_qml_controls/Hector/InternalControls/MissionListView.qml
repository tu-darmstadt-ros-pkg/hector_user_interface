import QtQuick 2.3
import QtQuick.Controls.Basic 2.1
import Hector.Utils 1.0
import Hector.Style 1.0

ListView {
    id: control

    property bool disableMouseSelection: true
    property int lastCount: 0
    property var style

    currentIndex: -1
    spacing: 0

    delegate: StyledButton {
        id: item

        property bool isCurrent: ListView.isCurrentItem

        flat: !ListView.isCurrentItem
        height: Units.pt(24)
        style: control.style
        width: parent.width

        onClicked: function () {
            if (!disableMouseSelection) {
                control.currentIndex = index;
            }
        }

        MissionTask {
            anchors.fill: parent
            current: item.isCurrent
            style: control.style
            task: modelData
        }
    }
    header: Button {
        id: headerButton
        height: Units.pt(24)
        width: parent.width

        background: Rectangle {
            color: Style.handleMouseStates(headerButton, control.currentIndex == -1 ? control.style.primary.color : Style.background.content)
            opacity: enabled ? 1.0 : 0.3
        }

        onClicked: control.currentIndex = -1

        MissionTask {
            anchors.fill: parent
            current: control.currentIndex == -1
            style: control.style
            task: ({
                    "name": "Start of Mission"
                })
        }
    }
}
