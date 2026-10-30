import QtQuick
import "NoteColors.js" as NoteColors

// Displays all notes of the NoteTool as clickable icons anchored to their 3D point and hosts
// the popup to create, edit and delete them. Works with any active rviz tool.
Item {
    id: root

    // Reads tools so the lookup re-runs when a config reload recreates every QmlTool wrapper.
    readonly property var tool: {
        if (!rviz || !rviz.toolManager)
            return null;
        rviz.toolManager.tools;
        var noteTool = rviz.toolManager.getTool("hector_user_interface/NoteTool");
        return noteTool ? noteTool.tool : null;
    }

    //! Opens the editor for the stored note beside anchor.
    function edit(note, anchor) {
        notePopup.edit(note, anchor, false);
    }

    Connections {
        function onNotePlaced(note) {
            notePopup.edit(note, draftMarker, true);
        }

        target: root.tool
    }
    Repeater {
        model: root.tool ? root.tool.notes : []

        delegate: NoteMarker {
            id: marker
            color: modelData.color || NoteColors.defaultColor
            note: modelData
            tool: root.tool

            onClicked: root.edit(modelData, marker)
        }
    }

    // Marks the position of a placed note until it is saved and gets its own marker.
    NoteMarker {
        id: draftMarker
        color: notePopup.selectedColor
        note: notePopup.visible && notePopup.isNew ? notePopup.note : null
        tool: root.tool
    }
    NotePopup {
        id: notePopup
        // Must stay a binding: a config reload replaces the tool and a captured handle would throw.
        tool: root.tool
    }
}
