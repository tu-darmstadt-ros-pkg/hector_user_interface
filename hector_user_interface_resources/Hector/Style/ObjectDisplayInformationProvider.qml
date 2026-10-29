import QtQuick 2.3
import QtQuick.Controls 2.1
import Hector.Utils 1.0

Object {
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
