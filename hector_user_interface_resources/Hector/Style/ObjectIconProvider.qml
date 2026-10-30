import QtQuick 2.3
import QtQuick.Controls.Basic 2.1
import Hector.Controls 1.0
import Hector.Utils 1.0
import Ros2 1.0

NonVisualItem {
    id: root

    property color color: "black"

    function lookup(type) {
        if (type == "manometer") {
            return textIcon.createObject(null, {
                    "text": Style.icons.manometer
                });
        }
        return textIcon.createObject(null, {
                "text": Style.icons.unknown
            });
    }

    Component {
        id: textIcon
        AutoSizeText {
            id: textIcon
            anchors.fill: parent
            color: root.color
            font.family: Style.iconFontFamily
        }
    }
    Component {
        id: imageIcon
        Image {
            property real margins

            anchors.fill: parent
            anchors.margins: margins
            sourceSize.height: height
            sourceSize.width: width
        }
    }
}
