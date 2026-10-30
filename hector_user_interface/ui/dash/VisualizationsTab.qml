import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import Hector.Controls
import Hector.InternalControls
import Hector.MultiRobot
import Hector.Style
import Hector.Utils
import "../visualizations/VisualizationTypes.js" as VisualizationTypes

Rectangle {
    id: root

    property Robot robot
    property var style

    // Cached so delegates can compare against the previous entry to place headers.
    property var visualizations: sortedVisualizations()

    // Sorted so entries of the same group are contiguous, ungrouped entries ("")
    // last. Group headers are rendered per delegate (ListView sections do not work
    // with a plain JS array model).
    function sortedVisualizations() {
        if (!root.robot)
            return [];
        let sorted = root.robot.visualizations.slice();
        sorted.sort(function (a, b) {
                if (a.group === b.group)
                    return 0;
                if (!a.group)
                    return 1;
                if (!b.group)
                    return -1;
                return a.group < b.group ? -1 : 1;
            });
        return sorted;
    }

    color: Style.background.content

    ListView {
        anchors.fill: parent
        clip: true
        model: root.visualizations
        spacing: Units.pt(2)

        delegate: Column {
            id: item

            // First entry of each non-empty group gets a header. Ungrouped ("")
            // entries sort last and never get one.
            property bool showHeader: modelData.group !== "" && (index === 0 || root.visualizations[index - 1].group !== modelData.group)
            property bool supported: !!VisualizationTypes.classIdFor(modelData)

            width: ListView.view.width

            Text {
                color: Style.getTextColor(Style.background.container)
                font: Style.fonts.subHeader
                height: visible ? implicitHeight + Units.pt(4) : 0
                leftPadding: Units.pt(4)
                text: modelData.group
                verticalAlignment: Text.AlignBottom
                visible: item.showHeader
                width: parent.width
            }
            Rectangle {
                color: Style.background.content
                implicitHeight: itemLayout.implicitHeight + Units.pt(8)
                opacity: supported ? 1 : 0.4
                width: parent.width

                RowLayout {
                    id: itemLayout
                    anchors {
                        bottomMargin: Units.pt(4)
                        fill: parent
                        leftMargin: Units.pt(8)
                        rightMargin: Units.pt(8)
                        topMargin: Units.pt(4)
                    }
                    Text {
                        Layout.alignment: Qt.AlignVCenter
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        text: modelData.name

                        SimpleToolTip {
                            text: modelData.topic + " (" + modelData.kind + ")" + (supported ? "" : "\nUnsupported visualization kind")
                        }
                    }
                    VisibilityModeSelector {
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        enabled: supported
                        mode: root.robot && root.robot.visualizationModes[modelData.key] || 0
                        style: root.style

                        onModeSelected: function (mode) {
                            root.robot.setVisualizationMode(modelData.key, mode);
                        }
                    }
                }
            }
        }
    }
}
