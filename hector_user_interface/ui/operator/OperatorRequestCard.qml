import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import Hector.Controls
import Hector.InternalControls
import Hector.Style
import Hector.Utils

// Presentational operator-prompt card. Used both as the bottom-right stack delegate
// and as the centered modal card. Carries no request state of its own; the parent
// feeds it the record fields and maps its signals back to finish().
Rectangle {
    id: card

    // Absolute second timestamp; 0 means no timeout.
    property real deadline: 0
    property bool dismissable: false
    property string message: ""
    // Shared notifying clock from the parent; referencing it re-evaluates remaining each second.
    property real now: 0
    // Array of { id, label, style } where style is a Style group (e.g. Style.safe).
    property var options: []
    readonly property real padding: Units.pt(12)
    property real remaining: deadline > 0 ? Math.max(0, deadline - now) : 0
    property int severity: 0

    // OperatorPrompt severities: SEVERITY_INFO=10, SEVERITY_WARNING=20, SEVERITY_ERROR=30
    readonly property color severityColor: {
        if (severity >= 30)
            return Style.colors.status.error;
        if (severity >= 20)
            return Style.colors.status.warn;
        return Style.colors.status.info;
    }
    // No distinct error glyph; ERROR reuses the warning glyph, distinguished by the red tint.
    readonly property string severityIcon: severity < 20 ? Style.icons.info : Style.icons.exclamation
    property string source: ""
    property string title: ""

    signal answered(string option)
    signal dismissed

    color: Style.background.content
    implicitHeight: mainLayout.implicitHeight + 2 * card.padding

    // Fixed width drives the message wrap; content never drives width (avoids the
    // content-implicitWidth <-> wrapping-Text-width binding loop).
    implicitWidth: Units.pt(360)

    border {
        color: severityColor
        width: Units.pt(1)
    }
    ColumnLayout {
        id: mainLayout
        anchors.fill: parent
        anchors.margins: card.padding

        RowLayout {
            Layout.fillWidth: true
            spacing: Units.pt(12)

            // Fill-height wrapper centers the badge via anchors (loop-free, unlike
            // Layout.alignment). The Icon lives in a plain Item so its explicit 40x40 is
            // honored; sized directly in a Layout it would use its ~1000pt implicit height.
            Item {
                Layout.fillHeight: true
                Layout.preferredWidth: Units.pt(40)
                implicitHeight: Units.pt(40)

                // Circular severity badge.
                Icon {
                    anchors.centerIn: parent
                    backgroundColor: card.severityColor
                    color: Style.getTextColor(card.severityColor)
                    height: Units.pt(40)
                    round: true
                    text: card.severityIcon
                    width: Units.pt(40)

                    font {
                        family: Style.iconFontFamily
                        pointSize: 24
                    }
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: Units.pt(2)

                Text {
                    Layout.bottomMargin: Units.pt(4)
                    Layout.fillWidth: true
                    font: Style.fonts.header
                    text: card.title
                    visible: card.title.length > 0
                    wrapMode: Text.Wrap
                }
                Text {
                    Layout.fillWidth: true
                    color: "#444444"
                    font: Qt.font({
                            "pointSize": 10
                        })
                    text: card.message
                    visible: card.message.length > 0
                    wrapMode: Text.Wrap
                }
                Text {
                    Layout.fillWidth: true
                    color: Style.colors.status.unknown
                    font: Style.fonts.tiny
                    text: Math.ceil(card.remaining) + "s remaining"
                    visible: card.remaining > 0
                }
            }
        }

        // Buttons pinned bottom-right; the leading spacer pushes them over. Single row
        // (no wrap): prompts carry at most a few short options, which shrink/elide if tight.
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: Units.pt(10)
            spacing: Units.pt(8)

            Text {
                Layout.fillWidth: true
                color: Style.colors.status.unknown
                elide: Text.ElideRight
                text: card.source
                visible: card.source.length > 0
            }
            Item {
                Layout.fillWidth: true
            }
            Repeater {
                model: card.options

                StyledButton {
                    Layout.preferredHeight: Units.pt(26)
                    leftPadding: Units.pt(12)
                    rightPadding: Units.pt(12)
                    style: modelData.style
                    text: modelData.label

                    onClicked: card.answered(modelData.id)
                }
            }
        }
    }

    // Dismiss (X), top-right corner. Overlaid so it never shifts the content layout.
    Text {
        color: dismissArea.containsMouse ? Style.colors.status.error : Style.colors.status.unknown
        text: Style.icons.close
        visible: card.dismissable

        anchors {
            margins: card.padding
            right: parent.right
            top: parent.top
        }
        font {
            family: Style.iconFontFamily
            pointSize: 20
        }
        MouseArea {
            id: dismissArea
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            hoverEnabled: true

            onClicked: card.dismissed()
        }
    }
}
