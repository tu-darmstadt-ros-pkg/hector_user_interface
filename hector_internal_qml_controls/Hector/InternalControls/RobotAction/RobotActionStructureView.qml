import QtQuick 2.3
import QtQuick.Controls.Basic 2.2
import QtQuick.Templates as T
import QtQuick.Layouts 1.1
import Hector.InternalControls 1.0
import Hector.InternalControls.RobotAction 1.0
import Hector.Controls 1.0
import Hector.Style 1.0
import Hector.Utils 1.0
import Hector.MultiRobot 1.0
import Ros2 1.0

Item {
    id: root

    property real cellHeight: Units.pt(40)
    property Item dragParent: root
    property bool editable: true
    property real minimumCellWidth: Units.pt(96)
    property Robot robot: null
    property var structure: ({
            "uuid": "root",
            "type": "directory",
            "content": []
        })
    property var style

    signal editActionRequested(string uuid)
    signal structureUpdated

    StackView {
        id: stackView
        anchors.fill: parent
        initialItem: behaviorView

        onBusyChanged: if (!busy && d.pendingPop) {
            d.pendingPop = false;
            Qt.callLater(d.closeDirectory);
        }
    }
    Component {
        id: behaviorView
        ColumnLayout {
            id: behaviorLayout

            //! Directory shown by this page, empty for the root. Looked up in the structure so edits show.
            property string directoryUuid: ""
            property var modelData: directoryUuid ? d.getStructureEntry(directoryUuid) : root.structure

            StackView.onRemoved: d.freeStackViewItems()

            ToolBar {
                Layout.fillWidth: true
                Layout.preferredHeight: Units.pt(32)
                visible: !!modelData && modelData.type === "directory" && modelData.uuid !== "root"

                RowLayout {
                    anchors.fill: parent

                    Item {
                        Layout.fillHeight: true
                        Layout.preferredWidth: Units.pt(32)

                        ToolButton {
                            id: backButton
                            anchors.fill: parent
                            text: Style.icons.goBack

                            onClicked: d.closeDirectory()

                            font {
                                family: Style.iconFontFamily
                            }
                        }
                        DropArea {
                            id: dropArea
                            anchors.fill: backButton
                            keys: ["RobotAction"]

                            onDropped: leaveDirectoryTimer.stop()
                            onEntered: leaveDirectoryTimer.restart()
                            onExited: leaveDirectoryTimer.stop()

                            Timer {
                                id: leaveDirectoryTimer
                                interval: 1000

                                onTriggered: d.closeDirectory()
                            }
                        }
                    }
                    Label {
                        Layout.fillWidth: true
                        font: Style.fonts.label
                        text: modelData && modelData.name || ""
                    }
                }
            }
            AutoSizeGridView {
                id: behaviorGrid
                Layout.fillHeight: true
                Layout.fillWidth: true
                cellMinimumWidth: root.minimumCellWidth
                keys: ["RobotAction"]
                model: modelData && modelData.content || []

                delegate: Component {
                    Item {
                        id: delegateRoot

                        property bool highlighted: false
                        property var model: modelData

                        // Approach used because of https://stackoverflow.com/questions/24532317/new-drag-and-drop-mechanism-does-not-work-as-expected-in-qt-quick-qt-5-3
                        // Does NOT fire dragStarted or dragFinished use dragArea.active instead!
                        Drag.dragType: Drag.None
                        Drag.keys: ["RobotAction"]
                        height: root.cellHeight
                        width: d.tileWidth

                        Menu {
                            id: contextMenu
                            MenuItem {
                                text: "Edit"

                                onTriggered: {
                                    if (modelData.type !== "directory")
                                        root.editActionRequested(modelData.key);
                                    else
                                        renameDirectoryDialog.show(modelData.uuid);
                                }
                            }
                            MenuItem {
                                text: "Delete"

                                onTriggered: d.removeStructureEntry(modelData.uuid)
                            }
                        }
                        MouseArea {
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            anchors.fill: parent
                            anchors.margins: Units.pt(4)
                            propagateComposedEvents: true

                            onClicked: function (mouse) {
                                if (mouse.button === Qt.RightButton)
                                    contextMenu.popup();
                            }
                            onPressAndHold: function (mouse) {
                                if (mouse.source === Qt.MouseEventNotSynthesized)
                                    contextMenu.popup();
                            }
                        }
                        MouseArea {
                            id: dragArea
                            anchors.fill: parent
                            anchors.margins: Units.pt(4)
                            drag.filterChildren: true
                            drag.target: parent
                            propagateComposedEvents: true

                            DropArea {
                                id: dropArea

                                property real lastX
                                property real lastY

                                anchors.fill: parent
                                keys: ["RobotAction"]

                                onDropped: function (drop) {
                                    enterDirectoryTimer.stop();
                                    if (drop.source == delegateRoot)
                                        return;
                                    delegateRoot.highlighted = false;
                                    drop.accept();
                                    if (delegateRoot.model.type !== "directory") {
                                        d.createDirectory(delegateRoot.model, drop.source.model);
                                    } else {
                                        d.moveItemToDirectory(delegateRoot.model, drop.source.model);
                                    }
                                }
                                onEntered: function (drag) {
                                    if (drag.source == delegateRoot)
                                        return;
                                    delegateRoot.highlighted = true;
                                    drag.accept();
                                    enterDirectoryTimer.restart();
                                    lastX = drag.x;
                                    lastY = drag.y;
                                }
                                onExited: {
                                    delegateRoot.highlighted = false;
                                    enterDirectoryTimer.stop();
                                }
                                onPositionChanged: function (drag) {
                                    if (Math.abs(drag.x - lastX) < Units.pt(4) && Math.abs(drag.y - lastY) < Units.pt(4))
                                        return;
                                    lastX = drag.x;
                                    lastY = drag.y;
                                    enterDirectoryTimer.restart();
                                }

                                // Directory rendering
                                Rectangle {
                                    id: directoryButton
                                    anchors.fill: parent
                                    clip: true
                                    color: delegateRoot.highlighted ? Style.handleMouseStates(directoryMouseArea, Style.activeStyle.primary.color) : Style.handleMouseStates(directoryMouseArea, Style.base.primary.color)
                                    visible: delegateRoot.model.type === "directory"

                                    Text {
                                        color: '#44888888'
                                        fontSizeMode: Text.Fit
                                        height: parent.height * 1.5
                                        horizontalAlignment: Text.AlignHCenter
                                        minimumPointSize: 6
                                        text: Style.icons.folder
                                        width: height
                                        x: -width / 4
                                        y: parent.height / 6

                                        font {
                                            family: Style.iconFontFamily
                                            pointSize: 100
                                        }
                                    }
                                    Text {
                                        anchors.fill: parent
                                        anchors.margins: Units.pt(4)
                                        color: Style.getTextColor(parent.color)
                                        elide: Text.ElideRight
                                        font: Style.button.font
                                        horizontalAlignment: Text.AlignHCenter
                                        text: delegateRoot.model.name || ""
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                    MouseArea {
                                        id: directoryMouseArea
                                        anchors.fill: parent
                                        hoverEnabled: true

                                        onClicked: d.openDirectory(delegateRoot.model)
                                    }
                                }

                                // Action rendering
                                ActionButton {
                                    id: actionButton
                                    anchors.fill: parent
                                    highlighted: delegateRoot.highlighted
                                    robot: root.robot
                                    robotAction: delegateRoot.model.type !== "directory" ? root.robot.actionManager.getAction(delegateRoot.model.key) : null
                                    visible: delegateRoot.model.type !== "directory"
                                }
                                Timer {
                                    id: enterDirectoryTimer
                                    interval: 1000

                                    onTriggered: {
                                        if (delegateRoot.model.type !== "directory")
                                            return;
                                        d.openDirectory(delegateRoot.model);
                                    }
                                }
                            }
                        }
                        Connections {
                            property var gridWorkaround: null // For some reason behaviorGrid can't be found after reparenting

                            function onActiveChanged() {
                                if (!gridWorkaround)
                                    gridWorkaround = behaviorGrid;
                                if (dragArea.drag.active) {
                                    dropArea.keys = ["IGNORE_GD23"];
                                    d.startDrag(dragArea);
                                } else {
                                    if (d.drop(dragArea) === Qt.IgnoreAction)
                                    // gridWorkaround.relayout()
                                    {
                                    }
                                    dropArea.keys = ["RobotAction"];
                                }
                            }

                            target: dragArea.drag
                        }
                    }
                }
                previewComponent: Component {
                    Item {
                        Rectangle {
                            color: "gray"
                            height: parent.height - Units.pt(8)
                            width: parent.width - Units.pt(8)
                            x: Units.pt(4)
                            y: Units.pt(4)
                        }
                    }
                }

                onItemDropped: function (drop, index) {
                    drop.accept();
                    if (!!drop.source.model) {
                        d.moveItemToDirectory(modelData, drop.source.model, index);
                    } else {
                        Ros2.error("Dropped RobotAction had no model set!");
                    }
                }
                onItemMoved: function (from, to) {
                    d.handleItemMoved(modelData, from, to);
                }
            }
        }
    }
    Dialog {
        id: renameDirectoryDialog

        property var item: null

        function show(uuid) {
            item = d.getStructureEntry(uuid);
            directoryName.text = item.name;
            open();
        }

        closePolicy: Popup.NoAutoClose
        focus: true
        parent: T.Overlay.overlay
        standardButtons: Dialog.Ok | Dialog.Cancel
        title: "Rename directory"
        // Center dialog
        x: parent.x + (parent.width - width) / 2
        y: parent.y + (parent.height - height) / 2

        onAccepted: {
            if (directoryName.text === "") {
                directoryName.focus = true;
                renameDirectoryDialog.visible = true;
                return;
            }
            d.renameDirectory(item.uuid, directoryName.text);
        }

        TextField {
            id: directoryName
            cursorVisible: focus
            selectByMouse: true

            onTextChanged: renameDirectoryDialog.standardButton(Dialog.Ok).enabled = text !== ''
        }
    }
    QtObject {
        id: d

        property bool dragActive: false
        property Item oldParent: null
        property bool pendingPop: false
        property real tileWidth: root.width / tilesPerRow

        // Properties for dynamic sizing
        property real tilesPerRow: Math.floor(root.width / root.minimumCellWidth)
        property var toRemove: []

        function _createDirectory(structure, dropTarget, dropItem) {
            if (structure.uuid === dropItem.uuid)
                return undefined;
            if (structure.type && structure.type != "directory") {
                if (structure.uuid !== dropTarget.uuid)
                    return structure;
                return {
                    "uuid": Uuid.generate(),
                    "type": "directory",
                    "name": "Unnamed",
                    "content": [dropTarget, toStructureEntry(dropItem)]
                };
            }
            for (var i = 0; i < structure.content.length; ++i) {
                structure.content[i] = _createDirectory(structure.content[i], dropTarget, dropItem);
            }
            structure.content = _filterStructureContent(structure.content);
            return structure;
        }

        // For debugging
        function _dumpStructure(structure, indentation) {
            if (!indentation)
                indentation = "";
            if (structure.type !== "directory") {
                console.log(indentation + "- " + structure.key);
                return;
            }
            console.log(indentation + "- " + (structure.uuid === "root" ? "Root" : structure.name) + ":");
            for (var i = 0; i < structure.content.length; ++i) {
                _dumpStructure(structure.content[i], indentation + " ");
            }
        }
        function _filterStructureContent(content) {
            // Array.from also accepts Qt sequences, which fail Array.isArray
            return Array.from(content || []).filter(Boolean);
        }
        function _getStructureEntry(structure, uuid) {
            if (structure.uuid === uuid)
                return structure;
            if (structure.type !== "directory")
                return undefined;
            for (var i = 0; i < structure.content.length; ++i) {
                var entry = _getStructureEntry(structure.content[i], uuid);
                if (entry)
                    return entry;
            }
            return undefined;
        }
        function _insertItemIntoStructure(structure, parent, item, index) {
            if (structure.type != "directory")
                return structure;
            if (structure.uuid === parent.uuid) {
                if (index == null || index >= structure.content.length)
                    structure.content.push(item);
                else
                    structure.content.splice(index, 0, item);
                return structure;
            }
            for (var i = 0; i < structure.content.length; ++i) {
                structure.content[i] = _insertItemIntoStructure(structure.content[i], parent, item, index);
            }
            return structure;
        }
        function _moveItemInStructure(structure, newParent, item, index) {
            if (structure.uuid === item.uuid)
                return undefined;
            if (structure.type !== "directory")
                return structure;
            for (var i = 0; i < structure.content.length; ++i) {
                structure.content[i] = _moveItemInStructure(structure.content[i], newParent, item, index);
            }
            structure.content = _filterStructureContent(structure.content);
            if (structure.uuid === newParent.uuid) {
                if (index !== null && index < structure.content.length)
                    structure.content.splice(index, 0, item);
                else
                    structure.content.push(item);
            }
            return structure;
        }
        function _removeStructureEntry(structure, uuid) {
            if (structure.uuid === uuid)
                return undefined;
            if (structure.type && structure.type != "directory")
                return structure;
            for (var i = 0; i < structure.content.length; ++i) {
                structure.content[i] = _removeStructureEntry(structure.content[i], uuid);
            }
            structure.content = _filterStructureContent(structure.content);
            return structure;
        }
        function _renameDirectory(structure, uuid, newName) {
            if (structure.type && structure.type != "directory")
                return structure;
            if (structure.uuid === uuid) {
                structure.name = newName;
            }
            for (var i = 0; i < structure.content.length; ++i) {
                structure.content[i] = _renameDirectory(structure.content[i], uuid, newName);
            }
            return structure;
        }
        function closeDirectory() {
            if (stackView.busy) {
                pendingPop = true;
                return;
            }
            var item = stackView.pop();
            if (!item)
                return;
            toRemove.push(item);
        }
        function commitStructure(structure) {
            // Deep copy: Qt 6 emits no change signal when re-assigning the same object, and the
            // pages of open subdirectories only refresh if their directory object is new as well.
            root.structure = JSON.parse(JSON.stringify(structure));
            root.structureUpdated();
        }
        function createDirectory(dropTarget, dropItem) {
            commitStructure(_createDirectory(root.structure, dropTarget, dropItem));
        }
        function drop(dragArea) {
            var item = dragArea.drag.target;
            var dropResult = item.Drag.drop();
            item.parent = oldParent;
            dragActive = false;
            freeStackViewItems();
            return dropResult;
        }
        function freeStackViewItems() {
            if (dragActive)
                return;
            for (var i = 0; i < toRemove.length; ++i) {
                toRemove[i].destroy();
            }
            toRemove.length = 0; // Clear toRemove list
        }
        function getStructureEntry(uuid) {
            return _getStructureEntry(root.structure, uuid);
        }
        function handleItemMoved(model, from, to) {
            commitStructure(_moveItemInStructure(root.structure, model, model.content[from], to));
        }
        function initActionStructure() {
            root.structure = {
                "uuid": "root",
                "type": "directory",
                "content": []
            };
        }
        function isStructureEntry(item) {
            return !!item.type && !!item.key;
        }
        function moveItemToDirectory(parent, item, index) {
            if (!root.structure.content) {
                initActionStructure();
                var structure = root.structure;
                structure.content.push(toStructureEntry(item));
                commitStructure(structure);
                return;
            }
            if (isStructureEntry(item)) {
                commitStructure(_moveItemInStructure(root.structure, parent, item, index));
            } else {
                commitStructure(_insertItemIntoStructure(root.structure, parent, toStructureEntry(item), index));
            }
        }
        function openDirectory(model) {
            if (stackView.busy)
                return;
            var item = null;
            // Try reusing the item if possible during drag navigation
            for (var i = 0; i < toRemove.length; ++i) {
                if (toRemove[i].directoryUuid !== model.uuid)
                    continue;
                item = toRemove[i];
                toRemove.splice(i, 1);
                break;
            }
            if (!item)
                item = behaviorView.createObject(stackView, {
                        "directoryUuid": model.uuid
                    });
            stackView.push(item);
        }
        function removeStructureEntry(uuid) {
            commitStructure(_removeStructureEntry(root.structure, uuid));
        }
        function renameDirectory(uuid, newName) {
            commitStructure(_renameDirectory(root.structure, uuid, newName));
        }
        function startDrag(dragArea) {
            var item = dragArea.drag.target;
            dragActive = true;
            var pos = item.mapFromItem(dragArea, dragArea.mouseX, dragArea.mouseY);
            oldParent = item.parent;
            item.parent = root.dragParent;
            item.Drag.active = true;
            item.Drag.hotSpot = pos;
            item.Drag.start();
        }
        function toStructureEntry(item) {
            if (item.type && (item.type == "directory" || item.type == "robotAction"))
                return item;
            if (item.uuid) {
                return {
                    "type": "robotAction",
                    "key": item.uuid,
                    "uuid": Uuid.generate()
                };
            }
            Ros2.error("Failed to create structure entry for: " + JSON.stringify(item));
        }
    }
}
