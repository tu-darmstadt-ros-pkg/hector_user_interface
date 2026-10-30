import QtQuick
import QtQuick.Controls.Basic
import Hector.Utils

NonVisualItem {
    id: root

    property color color: "black"
    property QtObject iconProvider: ObjectIconProvider {
        color: root.color
    }

    function lookup(type) {
        var name = type;
        if (type == "manometer") {
            name = "Manometer";
        }
        return {
            "name": name,
            "icon": iconProvider.lookup(type)
        };
    }
}
