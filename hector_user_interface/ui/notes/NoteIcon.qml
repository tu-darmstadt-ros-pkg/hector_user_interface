import QtQuick
import Hector.Controls
import Hector.Style

// Round note icon; set backgroundColor to the note color.
Icon {
    //! Style.icons key; empty or unknown shows the info icon.
    property string iconName: ""

    color: Style.getTextColor(backgroundColor)
    font.family: Style.iconFontFamily
    round: true
    text: Style.icons[iconName] || Style.icons.info
}
