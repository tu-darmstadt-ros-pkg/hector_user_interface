pragma Singleton
import QtQuick
import QtQuick.Controls.Material
import Hector.Icons
import Hector.Utils

NonVisualItem {
    id: root

    readonly property QtObject activeStyle: d.activeStyle

    // The following colors are picked from "Points of view: Color blindness" - Bang Wong (2011)
    // https://www.nature.com/articles/nmeth.1618
    readonly property QtObject autonomous: QtObject {
        property QtObject primary: QtObject {
            property color color: "#0072B2" // blue
            property color dark: Qt.darker(color, 1.2)
            property color light: Qt.lighter(color, 1.2)
        }
        property QtObject secondary: primary
    }
    readonly property QtObject background: QtObject {
        property color container: Material.color(Material.Grey, Material.Shade300)
        property color content: "white"
    }
    readonly property QtObject base: QtObject {
        property QtObject primary: QtObject {
            property color color: Material.color(Material.Grey, Material.Shade300)
            property color dark: Material.color(Material.Grey, Material.Shade500)
            property color light: Material.color(Material.Grey, Material.Shade100)
        }
        property QtObject secondary: primary
    }
    property QtObject battery: QtObject {
        property color background: Material.color(Material.Green, Material.Shade200)
        property color foregroundColor: Material.color(Material.Green, Material.Shade500)
    }
    property QtObject button: QtObject {
        property real defaultHeight: Units.pt(20)
        property font font: Qt.font({
                "weight": Font.ExtraBold,
                "pointSize": 11
            })
    }
    property QtObject colors: QtObject {
        property QtObject status: QtObject {
            property color error: Material.color(Material.Red)
            property color info: Material.color(Material.Blue)
            property color ok: Material.color(Material.Green)
            property color success: Material.color(Material.Green)
            property color unknown: Material.color(Material.BlueGrey)
            property color warn: Material.color(Material.Orange)
        }
    }
    property QtObject emergencyStop: QtObject {
        property color checkedColor: safe.primary.color
        property color uncheckedColor: Material.color(Material.Red, Material.Shade800)
    }

    /// =========================================================
    ///                          Controls
    /// =========================================================
    property QtObject fonts: QtObject {
        property font header: Qt.font({
                "weight": Font.Bold,
                "pointSize": 14
            })
        property font label: subHeader
        property font small: Qt.font({
                "pointSize": 9
            })
        property font subHeader: Qt.font({
                "weight": Font.Bold,
                "pointSize": 11
            })
        property font tiny: Qt.font({
                "pointSize": 8
            })
    }
    property QtObject header: QtObject {
        property font font: root.fonts.header
    }

    /// =========================================================
    ///                           Icons
    /// =========================================================
    readonly property string iconFontFamily: HectorIcons.fontFamily
    readonly property QtObject icons: QtObject {
        // For codes check: https://pictogrammers.github.io/@mdi/font/6.1.95/
        // Or use this to browse the font: http://mathew-kurian.github.io/CharacterMap/
        property string arrow: iconFromCharCode(0xf0731)
        property string arrowDoubleRight: iconFromCharCode(0xf013e)
        property string arrowDropDown: iconFromCharCode(0xf004a)
        property string arrowDropUp: iconFromCharCode(0xf0062)
        property string automaticFlippers: iconFromCharCode(0xf137e)
        property string camera: iconFromCharCode(0xf0d5d)
        property string cancel: iconFromCharCode(0xF0667)
        property string canceled: iconFromCharCode(0xF073A)
        property string check: iconFromCharCode(0xf012c)
        property string clockAlert: iconFromCharCode(0xF05CE)
        property string close: iconFromCharCode(0xF015A)
        property string co2: iconFromCharCode(0xF07E4)
        property string cube: iconFromCharCode(0xf0147)
        property string download: iconFromCharCode(0xf01da)
        property string edit: iconFromCharCode(0xf1782)
        property string exclamation: iconFromCharCode(0xf1238)
        property string eye: iconFromCharCode(0xf06d0)
        property string eyeOff: iconFromCharCode(0xf06d1)
        property string eyeOutline: iconFromCharCode(0xf0b95)
        property string flag: iconFromCharCode(0xf023f)
        property string folder: iconFromCharCode(0xf024b)
        property string gamepad: iconFromCharCode(0xf05bA)
        property string gearClockwise: iconFromCharCode(0xf11dd)
        property string gears: iconFromCharCode(0xf08d6)
        property string goBack: iconFromCharCode(0xf004e)
        property string info: iconFromCharCode(0xf064e)
        property string listNumbered: iconFromCharCode(0xf027b)
        property string location: iconFromCharCode(0xf12fc)
        property string lockClosed: iconFromCharCode(0xf033e)
        property string lockOpen: iconFromCharCode(0xf0fc6)
        property string magnet: iconFromCharCode(0xF0347)
        property string manometer: iconFromCharCode(0xf029a)
        property string map: iconFromCharCode(0xf034d)
        property string mapCheck: iconFromCharCode(0xf0ebc)
        property string measurement: iconFromCharCode(0xf046d)
        property string microphone: iconFromCharCode(0xf036e)
        property string minus: iconFromCharCode(0xf0374)
        property string missionStart: iconFromCharCode(0xf071d)
        property string monitorEye: iconFromCharCode(0xf13b4)
        property string move: iconFromCharCode(0xf01be)
        property string next: iconFromCharCode(0xf04ad)
        property string pause: iconFromCharCode(0xf03e4)
        property string pauseSnooze: iconFromCharCode(0xf068e)
        property string pencil: iconFromCharCode(0xf064f)
        property string pencilRuler: iconFromCharCode(0xf1353)
        property string photo: iconFromCharCode(0xf02e9)
        property string play: iconFromCharCode(0xf040a)
        property string plus: iconFromCharCode(0xf0415)
        property string previous: iconFromCharCode(0xf04ae)
        property string radiation: iconFromCharCode(0xF043C)
        property string redo: iconFromCharCode(0xf044e)
        property string robot: iconFromCharCode(0xf0b46)
        property string robotAction: iconFromCharCode(0xF17F2)
        property string rotate: iconFromCharCode(0xf0d98)
        property string save: iconFromCharCode(0xf0193)
        property string settings: iconFromCharCode(0xf08d6)
        property string speed: iconFromCharCode(0xf04c5)
        property string stability: iconFromCharCode(0xf05d1)
        property string star: iconFromCharCode(0xf04ce)
        property string stop: iconFromCharCode(0xf04db)
        property string trash: iconFromCharCode(0xF09E7)
        property string trashOpen: iconFromCharCode(0xF0E9D)
        property string undo: iconFromCharCode(0xf054c)
        property string unknown: iconFromCharCode(0xf02d6)
        property string upload: iconFromCharCode(0xf0552)
        property string video: iconFromCharCode(0xf0567)
        property string viewController: iconFromCharCode(0xf0b69)
        property string viewControllerBack: iconFromCharCode(0xf0737)
        property string viewControllerFront: iconFromCharCode(0xf072e)
        property string viewControllerLeft: iconFromCharCode(0xf0734)
        property string viewControllerRight: iconFromCharCode(0xf0731)
        property string wifiAlert: iconFromCharCode(0xF16B5)
    }
    property QtObject listElement: QtObject {
        property int height: Units.pt(24)
        property font subtitleFont: Qt.font({
                "pointSize": 9
            })
        property font titleFont: Qt.font({
                "weight": Font.Bold,
                "pointSize": 11
            })
    }
    readonly property QtObject manipulation: QtObject {
        property QtObject primary: QtObject {
            property color color: "#D55E00" // vermillion
            property color dark: Qt.darker(color, 1.2)
            property color light: Qt.lighter(color, 1.2)
        }
        property QtObject secondary: primary
    }
    property QtObject missionPlanning: autonomous
    property QtObject popup: QtObject {
        property double borderWidth: Units.pt(1)
    }
    readonly property QtObject safe: QtObject {
        property QtObject primary: QtObject {
            property color color: "#009E73" // bluish green
            property color dark: Qt.darker(color, 1.2)
            property color light: Qt.lighter(color, 1.2)
        }
        property QtObject secondary: primary
    }
    readonly property QtObject sitesetup: QtObject {
        property QtObject primary: QtObject {
            property color color: "#56B4E9" // skyblue
            property color dark: Qt.darker(color, 1.2)
            property color light: Qt.lighter(color, 1.2)
        }
        property QtObject secondary: primary
    }
    property QtObject subHeader: QtObject {
        property font font: root.fonts.subHeader
    }
    readonly property QtObject teleoperation: QtObject {
        property QtObject primary: QtObject {
            property color color: "#E69F00" // orange
            property color dark: Qt.darker(color, 1.2)
            property color light: Qt.lighter(color, 1.2)
        }
        property QtObject secondary: primary
    }

    function buttonStyle(style) {
        return {
            "color": style.secondary.color,
            "uncheckedColor": style.secondary.light,
            "checkedColor": style.secondary.dark
        };
    }
    function getTextColor(color) {
        if (color.hslLightness > 0.8)
            return "black";
        return "white";
    }

    /// =========================================================
    ///                           Colors
    /// =========================================================
    function handleMouseStates(control, baseColor, checkedColor) {
        var color = control.checked ? (checkedColor ? checkedColor : Qt.lighter(baseColor, 1.2)) : baseColor;
        if (color.hslLightness > 0.8) {
            if (control.down)
                return Qt.darker(color, 1.3);
            if (control.hovered)
                return Qt.darker(color, 1.15);
            if (control.highlighted)
                return Qt.darker(color, 1.5);
            return color;
        }
        if (control.down)
            return Qt.darker(color, 1.15);
        if (control.hovered)
            return Qt.lighter(color, 1.15);
        if (control.highlighted)
            return Qt.lighter(color, 1.5);
        return color;
    }
    function iconFromCharCode(codePt) {
        if (codePt > 0xFFFF) {
            codePt -= 0x10000;
            return String.fromCharCode(0xD800 + (codePt >> 10), 0xDC00 + (codePt & 0x3FF));
        }
        return String.fromCharCode(codePt);
    }
    function iconToCharCode(icon) {
        if (!icon || !icon.length || icon.length === 0)
            return 0;
        if (icon.length === 1) {
            return icon.charCodeAt(0);
        }
        var a = icon.charCodeAt(0);
        var b = icon.charCodeAt(1);
        return 0x10000 + ((a - 0xD800) << 10) + b - 0xDC00;
    }
    function setActiveStyle(style) {
        if (style === d.activeStyle)
            return;
        d.activeStyle = style;
    }

    QtObject {
        id: d

        property QtObject activeStyle: teleoperation
    }
}
