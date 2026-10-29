import QtQuick 2.3
import QtQuick.Controls 2.3
import QtQuick.Layouts 1.1
import Hector.Utils 1.0
import Hector.Style 1.0
import "NoteColors.js" as NoteColors

// Non-modal create/edit/delete dialog for one note, popping out beside an anchor item on the
// side that has room.
Dialog {
    id: root

    readonly property real gap: Units.pt(6)
    //! Style.icons key; empty means unset.
    property string iconName: ""
    //! The note is a draft from notePlaced that is not stored until saved.
    property bool isNew: false
    property var note: null
    //! Style.icons keys offered by the pill selector.
    readonly property var noteIcons: ["info", "exclamation", "flag", "location", "lockClosed", "unknown", "radiation", "co2"]
    property bool onLeft: false
    // The color value, never an index: a hand-edited file can carry a color outside the palette.
    property string selectedColor: ""
    property var tool: null

    //! Opens the popup next to anchor and populates the fields from note. Unsaved edits of a
    //! different note that is still open are dropped.
    function edit(note, anchor, isNew) {
        if (root.opened && root.note.id === note.id) {
            textArea.forceActiveFocus();
            return;
        }
        close();
        root.isNew = isNew;
        root.note = note;
        root.iconName = note.icon || "";
        root.selectedColor = note.color || NoteColors.defaultColor;
        textArea.text = note.text || "";
        root.parent = anchor;
        var bounds = root.Overlay.overlay;
        root.onLeft = !!bounds && anchor.mapToItem(bounds, anchor.width + gap + width, 0).x > bounds.width;
        open();
    }

    closePolicy: Popup.NoAutoClose
    focus: true
    height: Units.pt(220)
    margins: Units.pt(4)
    modal: false

    // Delete does not exist for a new note; there it would be identical to Cancel.
    standardButtons: isNew ? (Dialog.Save | Dialog.Cancel) : (Dialog.Save | Dialog.Cancel | Dialog.Discard)
    width: Units.pt(260)
    x: parent ? (onLeft ? -width - gap : parent.width + gap) : 0
    y: parent ? (parent.height - height) / 2 : 0

    onAccepted: {
        if (!root.tool)
            return;
        root.tool.saveNote({
                "id": root.note.id,
                "frame": root.note.frame,
                "position": root.note.position,
                "icon": root.iconName,
                "color": root.selectedColor,
                "text": textArea.text
            });
    }
    onDiscarded: {
        // discarded() does not close a Dialog by itself.
        if (root.tool)
            root.tool.removeNote(root.note);
        close();
    }

    // The click that placed the note took key focus; without it, typing would switch rviz tools.
    onOpened: {
        rviz.requestKeyFocus();
        textArea.forceActiveFocus();
    }
    // Changing standardButtons recreates the buttons, so text and enabled state are re-applied here.
    // Renaming at any later point leaves the button box layout stale.
    onStandardButtonsChanged: {
        var writable = function () {
            return !!root.tool && !root.tool.notesReadOnly;
        };
        var del = standardButton(Dialog.Discard);
        if (del) {
            del.text = "Delete";
            del.enabled = Qt.binding(writable);
        }
        var save = standardButton(Dialog.Save);
        if (save)
            save.enabled = Qt.binding(writable);
    }

    // A config reload recreates the tool and all markers, including the anchor.
    onToolChanged: if (opened)
        close()

    Connections {
        // Closes once the edited note is removed. Drafts are not stored yet, so they are skipped.
        function onNotesChanged() {
            if (!root.visible || root.isNew)
                return;
            var exists = root.tool.notes.some(function (n) {
                    return n.id === root.note.id;
                });
            if (!exists)
                root.close();
        }

        target: root.tool
    }
    ColumnLayout {
        anchors.fill: parent

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: Units.pt(24)

            // The note's current icon; clicking it opens the pill selector below.
            NoteIcon {
                id: currentIcon
                Layout.preferredHeight: Units.pt(24)
                Layout.preferredWidth: Units.pt(24)
                backgroundColor: root.selectedColor
                iconName: root.iconName

                MouseArea {
                    anchors.fill: parent

                    onClicked: iconPills.open()
                }
                Popup {
                    id: iconPills
                    margins: Units.pt(4)
                    padding: Units.pt(4)
                    y: parent.height + Units.pt(2)

                    contentItem: Row {
                        spacing: Units.pt(4)

                        Repeater {
                            model: root.noteIcons

                            delegate: NoteIcon {
                                backgroundColor: modelData === root.iconName ? root.selectedColor : "#e0e0e0"
                                height: Units.pt(24)
                                iconName: modelData
                                width: Units.pt(24)

                                MouseArea {
                                    anchors.fill: parent

                                    onClicked: {
                                        root.iconName = modelData;
                                        iconPills.close();
                                    }
                                }
                            }
                        }
                    }
                }
            }
            Item {
                Layout.fillWidth: true
            }
            Repeater {
                model: NoteColors.palette

                delegate: Rectangle {
                    Layout.preferredHeight: Units.pt(18)
                    Layout.preferredWidth: Units.pt(18)
                    border.color: modelData === root.selectedColor ? Style.getTextColor(modelData) : "black"
                    border.width: modelData === root.selectedColor ? Units.pt(2) : 1
                    color: modelData
                    radius: Units.pt(2)

                    MouseArea {
                        anchors.fill: parent

                        onClicked: root.selectedColor = modelData
                    }
                }
            }
        }
        Rectangle {
            Layout.fillHeight: true
            Layout.fillWidth: true

            border {
                color: "black"
                width: 1
            }
            ScrollView {
                anchors.fill: parent

                TextArea {
                    id: textArea
                    cursorVisible: focus
                    selectByMouse: true
                    wrapMode: TextEdit.Wrap
                }
            }
        }
        Text {
            Layout.fillWidth: true
            color: Style.colors.status.error
            font: Style.fonts.label
            text: root.tool ? root.tool.notesError : ""
            visible: text !== ""
            wrapMode: Text.Wrap
        }
    }
}
