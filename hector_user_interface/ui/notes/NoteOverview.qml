import QtQuick 2.3
import QtQuick.Controls.Basic 2.3
import QtQuick.Layouts 1.1
import Hector.InternalControls 1.0
import Hector.MultiRobot 1.0
import Hector.Style 1.0
import Hector.Utils 1.0
import Ros2 1.0
import "NoteColors.js" as NoteColors

// Lists all notes to open them, move the camera to one, or delete all of them.
Dialog {
    id: root

    readonly property var notes: tool ? tool.notes : []
    property var tool: null

    //! The operator wants to edit note; anchor is its row.
    signal openRequested(var note, var anchor)

    function moveTo(note) {
        var pose = root.tool.viewPose(note);
        if (!pose.valid) {
            // shortcut: log only, show to the operator once a shared notification mechanism exists.
            Ros2.warn("Cannot move to note: no transform for its frame '" + note.frame + "'.");
            return;
        }
        OcsManager.moveCameraTo(pose.eye, pose.focus, "");
    }

    closePolicy: Popup.CloseOnEscape
    margins: Units.pt(8)
    modal: false
    standardButtons: Dialog.Discard | Dialog.Close
    title: "Notes (" + notes.length + ")"
    width: Units.pt(260)

    onDiscarded: confirmClear.open()
    // Renamed when the buttons are created; a later rename leaves the button box layout stale.
    onStandardButtonsChanged: {
        var del = standardButton(Dialog.Discard);
        del.text = "Delete all";
        del.enabled = Qt.binding(function () {
                return root.notes.length > 0 && !!root.tool && !root.tool.notesReadOnly;
            });
    }

    ListView {
        id: list
        anchors.fill: parent
        clip: true
        model: root.notes
        spacing: Units.pt(8)

        ScrollBar.vertical: ScrollBar {
        }
        delegate: RowLayout {
            id: row
            spacing: Units.pt(8)
            width: list.width

            NoteIcon {
                Layout.preferredHeight: Units.pt(24)
                Layout.preferredWidth: Units.pt(24)
                backgroundColor: modelData.color || NoteColors.defaultColor
                iconName: modelData.icon
            }
            Text {
                Layout.fillWidth: true
                elide: Text.ElideRight
                font.italic: !modelData.text
                maximumLineCount: 2
                text: modelData.text || "No text"
                wrapMode: Text.Wrap
            }
            StyledRoundButton {
                Layout.preferredHeight: Units.pt(24)
                Layout.preferredWidth: Units.pt(24)
                font.family: Style.iconFontFamily
                padding: 0
                text: Style.icons.edit

                onClicked: root.openRequested(modelData, row)
            }
            StyledRoundButton {
                Layout.preferredHeight: Units.pt(24)
                Layout.preferredWidth: Units.pt(24)
                font.family: Style.iconFontFamily
                padding: 0
                text: Style.icons.video

                onClicked: root.moveTo(modelData)
            }
        }
    }
    Dialog {
        id: confirmClear
        modal: true
        standardButtons: Dialog.Yes | Dialog.No
        title: "Delete all " + root.notes.length + " notes?"
        x: (parent.width - width) / 2
        y: (parent.height - height) / 2

        onAccepted: {
            root.tool.clearNotes();
            root.close();
        }
    }
}
