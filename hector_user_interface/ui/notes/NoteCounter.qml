import QtQuick 2.3
import QtQuick.Controls 2.3
import Hector.InternalControls 1.0
import Hector.Style 1.0
import Hector.Utils 1.0

// Button showing the number of notes; opens the note overview below itself.
StyledRoundButton {
    id: root

    property var tool: null

    //! The operator wants to edit note; anchor is its row in the overview.
    signal openRequested(var note, var anchor)

    height: Units.pt(24)
    leftPadding: Units.pt(8)
    rightPadding: Units.pt(8)
    style: Style.activeStyle
    visible: !!tool && tool.notes.length > 0

    contentItem: Row {
        spacing: Units.pt(4)

        Text {
            anchors.verticalCenter: parent.verticalCenter
            color: Style.getTextColor(root.background.color)
            font.family: Style.iconFontFamily
            font.pointSize: 12
            text: Style.icons.info
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            color: Style.getTextColor(root.background.color)
            font: Style.fonts.label
            text: root.tool ? root.tool.notes.length : 0
        }
    }

    onClicked: overview.visible ? overview.close() : overview.open()

    NoteOverview {
        id: overview
        // Shrinks to the space below the button, else Popup shifts it up over the button.
        // Not y: the popup rewrites it when repositioning.
        height: {
            var bounds = root.Overlay.overlay;
            if (!bounds)
                return Units.pt(320);
            var below = bounds.height - root.mapToItem(bounds, 0, root.height).y;
            return Math.min(Units.pt(320), below - Units.pt(16));
        }
        tool: root.tool
        x: root.width - width
        y: root.height + Units.pt(8)

        onOpenRequested: function (note, anchor) {
            root.openRequested(note, anchor);
        }
    }
}
