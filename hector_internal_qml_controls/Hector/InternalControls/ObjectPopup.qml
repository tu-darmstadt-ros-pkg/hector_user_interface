import QtQuick 2.3
import QtQuick.Controls 2.1
import QtQuick.Layouts 1.1
import Hector.Controls 1.0
import Hector.Style 1.0
import Ros2 1.0

Popup {
    id: root

    property QtObject actionProvider: QtObject {
        function getActionsForObject(class_id, callback) {
            // Actions are a list of objects with name and value attributes.
            // For each action a button is generated with the name as text and on click the signal
            // actionSelected is emitted with the value of the action.
            // The callback has to be called at some point or the popup will be stuck loading the actions.
            // If there are no actions for this object class, pass an empty array '[]'.
            const actions = [];
            callback(actions);
        }
    }
    property alias backgroundColor: backgroundItem.color
    property QtObject objectDisplayInformationProvider: ObjectDisplayInformationProvider {
        color: style.primary.color
    }
    property var objectProvider
    property string objectServiceTopic
    property var style

    signal actionSelected(string object_id, var value)

    function show(id) {
        internal.obj = null;
        objectProvider.lookupAsync(id, function (obj) {
                internal.obj = obj;
                actionProvider.getActionsForObject(obj.class_id, function (result) {
                        internal.actions = result;
                    });
                var displayInformation = objectDisplayInformationProvider.lookup(obj.class_id);
                displayInformation.icon.parent = iconRectangle;
                displayInformation.icon.margins = 6;
                internal.displayInformation = displayInformation;
                iconRectangle.children.length = 0;
                iconRectangle.children.push(displayInformation.icon);
            });
        open();
    }

    padding: Units.pt(4)
    width: Units.pt(128)

    background: Rectangle {
        id: backgroundItem
        anchors.fill: parent
        color: Style.background.content

        border {
            color: root.style.primary.color
            width: Style.popup.borderWidth
        }
    }

    QtObject {
        id: internal

        property var actions: null
        property var displayInformation: null
        property bool loading: obj == null || actions == null
        property var obj: null
    }
    ColumnLayout {
        id: rootLayout
        anchors.fill: parent

        RowLayout {
            Layout.fillWidth: true

            SkeletonLoader {
                loading: internal.loading

                control: Rectangle {
                    id: iconRectangle
                    height: Units.pt(24)
                    width: Units.pt(24)
                }
            }
            ColumnLayout {
                Layout.alignment: Qt.AlignVCenter
                Layout.fillWidth: true
                spacing: 0

                SkeletonText {
                    id: objectTypeText
                    color: root.style.primary.color
                    font.pointSize: 10
                    font.weight: Font.Bold
                    text: !internal.displayInformation ? "" : internal.displayInformation.name
                    width: Units.pt(50)
                }
                SkeletonText {
                    id: objectNameText
                    font.pointSize: 12
                    text: !internal.obj ? "" : internal.obj.name
                    width: Units.pt(80)
                }
            }
        }
        ListView {
            Layout.fillWidth: true
            implicitHeight: childrenRect.height
            interactive: height != childrenRect.height
            model: internal.actions || [{}, {}, {}]
            spacing: Units.pt(2)
            visible: internal.actions == null || internal.actions.length > 0
            width: parent.width

            delegate: SkeletonLoader {
                loading: internal.loading
                width: parent.width

                StyledButton {
                    style: root.style
                    text: modelData.name || ""

                    onClicked: root.actionSelected(internal.obj.object_id, modelData.value)
                }
            }
        }
        Text {
            Layout.alignment: Qt.AlignHCenter
            Layout.margins: Units.pt(8)
            text: "No actions available."
            visible: internal.actions != null && internal.actions.length == 0
        }
    }
}
