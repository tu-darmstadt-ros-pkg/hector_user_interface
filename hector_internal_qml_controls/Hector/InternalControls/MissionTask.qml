import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import Hector.Controls
import Hector.Utils
import Hector.Style
import Ros2

Item {
    id: control

    property bool current: false
    //! Optional ObjectProvider used to resolve object_id params to display names
    property var objectProvider: null
    property var style
    property var task

    function getIconForTask(task) {
        if (task.name == "Take Measurement of Poi")
            return Style.icons.measurement;
        if (task.name == "Take Photo of Object")
            return Style.icons.photo;
        if (task.name == "Start of Mission")
            return Style.icons.missionStart;
        return Style.icons.unknown;
    }
    function getSubtitleForTask(task) {
        if (task.name == "Take Measurement of Poi" || task.name == "Take Photo of Object")
            return task.name;
        return "";
    }
    function getTitleForTask(task) {
        if (task.name == "Take Measurement of Poi" || task.name == "Take Photo of Object") {
            if (!control.objectProvider)
                return task.name;
            for (var i in task.params) {
                if (task.params[i].key != "object_id")
                    continue;
                return control.objectProvider.lookup(task.params[i].value).name;
            }
            Ros2.error("Did not find object_id param for task: " + task.name);
            return "Error";
        }
        return task.name;
    }

    RowLayout {
        anchors.fill: parent

        Icon {
            Layout.alignment: Qt.AlignVCenter
            Layout.fillHeight: true
            Layout.margins: Units.pt(4)
            Layout.preferredWidth: height
            backgroundColor: control.current ? Style.getTextColor(control.style.primary.color) : control.style.primary.color
            color: control.current ? control.style.primary.color : Style.getTextColor(control.style.primary.color)
            font.family: Style.iconFontFamily
            padding: Units.pt(2)
            text: getIconForTask(control.task)
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            Text {
                Layout.fillWidth: true
                color: Style.getTextColor(control.current ? control.style.primary.color : Style.background.content)
                font: Style.listElement.titleFont
                text: getTitleForTask(control.task)
            }
            Text {
                Layout.fillWidth: true
                color: Style.getTextColor(control.current ? control.style.primary.color : Style.background.content)
                font: Style.listElement.subtitleFont
                opacity: 0.8
                text: getSubtitleForTask(control.task)
                visible: text && text != ""
            }
        }
    }
}
