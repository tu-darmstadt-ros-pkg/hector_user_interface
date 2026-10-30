import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import Hector.InternalControls
import Hector.Controls
import Hector.Utils
import Hector.Style

Dialog {
    id: root

    property string icon

    closePolicy: Popup.NoAutoClose
    focus: true
    height: Units.pt(360)
    standardButtons: Dialog.Ok | Dialog.Cancel
    width: Units.pt(240)

    GridLayout {
        anchors.fill: parent
        columns: 2

        AutoSizeText {
            Layout.preferredHeight: Units.pt(16)
            Layout.preferredWidth: Units.pt(16)
            font.family: Style.iconFontFamily
            text: root.icon
        }
        ColumnLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: implicitHeight

            TextField {
                Layout.fillWidth: true
                text: root.icon && Style.iconToCharCode(root.icon).toString(16) || ''

                onTextChanged: {
                    if (text.length > 5)
                        return;
                    var number = parseInt(text, 16);
                    if (isNaN(number))
                        return;
                    root.icon = Style.iconFromCharCode(number);
                }
            }
            Text {
                text: 'For codes <a href="https://cdn.materialdesignicons.com/5.1.45/">check here</a>'

                onLinkActivated: function (link) { Qt.openUrlExternally(link) }
            }
        }
        ListView {
            Layout.columnSpan: 2
            Layout.fillHeight: true
            Layout.fillWidth: true
            clip: true
            model: {
                var result = [];
                for (var prop in Style.icons) {
                    if (prop === 'objectName' || typeof Style.icons[prop] !== 'string')
                        continue;
                    result.push({
                            "name": prop,
                            "icon": Style.icons[prop]
                        });
                }
                return result;
            }

            delegate: StyledButton {
                flat: true

                onClicked: root.icon = modelData.icon

                RowLayout {
                    Text {
                        font.family: Style.iconFontFamily
                        text: modelData.icon
                    }
                    Text {
                        text: modelData.name
                    }
                }
            }
        }
    }
}
