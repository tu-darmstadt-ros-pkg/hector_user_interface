import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import Hector.Controls
import Hector.InternalControls
import Hector.Utils
import Hector.Style
import Hector.MultiRobot

// Help popup showing a robot's gamepad mapping as a labelled controller diagram.
Popup {
    id: root

    //! Plate drawn behind the diagram's callout groups and the profile buttons so their text stays
    //! readable over whatever the transparent popup sits on.
    property color labelBackgroundColor: Qt.rgba(1, 1, 1, 0.8)

    //! Robot whose mapping is shown.
    property Robot robot: RobotManager.activeRobot

    //! Fill of the profile button for the config the diagram is showing. Picks the active style's
    //! color up at the same transparency as the other plates.
    property color selectedProfileColor: Qt.rgba(Style.activeStyle.primary.color.r, Style.activeStyle.primary.color.g, Style.activeStyle.primary.color.b, root.labelBackgroundColor.a)

    background: null

    onClosed: d.followActiveConfig()
    onRobotChanged: d.followActiveConfig()

    QtObject {
        id: d

        readonly property string activeConfig: root.robot ? root.robot.joyProfile : ""
        readonly property var configNames: mapping ? mapping.configs.map(function (config) {
                return config.name;
            }) : []

        // Every bound action of the selected config, keyed by control.
        readonly property var controlLabels: {
            var result = ({});
            var config = findConfig(selectedConfig);
            if (config) {
                config.buttons.forEach(function (button) {
                        var key = nameToControl[button.name];
                        if (!key)
                            return;
                        button.actions.forEach(function (action) {
                                pushRow(result, key, eventBadge[action.event] || "", action.description || action.function);
                            });
                    });
                config.axes.forEach(function (axis) {
                        var key = nameToControl[axis.name];
                        if (key)
                            pushRow(result, key, "", axis.description || axis.function);
                    });
            }
            if (mapping)
                mapping.config_switches.forEach(function (config_switch) {
                        var key = nameToControl[config_switch.name];
                        if (key)
                            pushRow(result, key, "⇄", "Switch to " + config_switch.config);
                    });
            return result;
        }

        // GamepadAction.event -> badge. EVENT_PRESS carries no badge.
        readonly property var eventBadge: ({
                0: "",
                1: "2×",
                2: "hold",
                3: "rel"
            })
        readonly property var mapping: root.robot ? root.robot.joyMapping : null

        // Canonical input name (the mapping message's `name` field) -> control key. A stick's axes and
        // its four virtual buttons (an axis pushed past its deadzone) fold onto the stick they read
        // from; the d-pad's four buttons keep their direction, and clicking a stick is its own control,
        // so each gets its own glyph. Names the diagram has no glyph for - paddle1-4, touchpad - are
        // absent, and a binding on one is left out of the popup.
        readonly property var nameToControl: ({
                "a": "a",
                "b": "b",
                "x": "x",
                "y": "y",
                "left_bumper": "lb",
                "right_bumper": "rb",
                "left_trigger": "lt",
                "right_trigger": "rt",
                "back": "back",
                "start": "start",
                "guide": "guide",
                "share": "share",
                "left_stick_click": "lstick_click",
                "right_stick_click": "rstick_click",
                "left_stick_x": "lstick",
                "left_stick_y": "lstick",
                "left_stick_left": "lstick",
                "left_stick_right": "lstick",
                "left_stick_up": "lstick",
                "left_stick_down": "lstick",
                "right_stick_x": "rstick",
                "right_stick_y": "rstick",
                "right_stick_left": "rstick",
                "right_stick_right": "rstick",
                "right_stick_up": "rstick",
                "right_stick_down": "rstick",
                "dpad_left": "dpad_left",
                "dpad_right": "dpad_right",
                "dpad_up": "dpad_up",
                "dpad_down": "dpad_down"
            })

        // Config-switch buttons are reserved in every config, so they are always shown.
        readonly property var reservedControls: {
            var keys = [];
            if (mapping)
                mapping.config_switches.forEach(function (config_switch) {
                        var key = nameToControl[config_switch.name];
                        if (key && keys.indexOf(key) < 0)
                            keys.push(key);
                    });
            return keys;
        }

        // Config the diagram currently shows. Follows the active profile until the user overrides it.
        property string selectedConfig: ""
        property bool userSelected: false

        function findConfig(name) {
            if (!mapping)
                return null;
            return mapping.configs.find(function (config) {
                    return config.name === name;
                }) || null;
        }

        // Show the robot's active profile again, dropping any config the user picked in the switcher.
        function followActiveConfig() {
            userSelected = false;
            selectedConfig = activeConfig;
        }
        function pushRow(target, key, badge, text) {
            if (!target[key])
                target[key] = [];
            var rows = target[key];
            for (var i = 0; i < rows.length; ++i)
                if (rows[i].badge === badge && rows[i].text === text)
                    // dedup identical rows (e.g. an axis bound as both axis and virtual button)
                    return;
            rows.push({
                    "badge": badge,
                    "text": text
                });
        }

        Component.onCompleted: followActiveConfig()
        onActiveConfigChanged: if (!userSelected && activeConfig)
            selectedConfig = activeConfig
    }

    // The popup has no background of its own, so almost all of what looks like the application behind
    // it is in fact the popup itself and never reaches the modal overlay's press-outside handling.
    // Dismiss on any click the profile buttons stacked above this do not take for themselves.
    MouseArea {
        anchors.fill: parent

        onClicked: root.close()
    }
    ColumnLayout {
        anchors.fill: parent
        spacing: Units.pt(6)

        // Profile switcher. The buttons are their own plates, styled like the diagram's callout groups
        // so the popup stays see-through around them.
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: Units.pt(4)

            Repeater {
                model: d.configNames

                delegate: StyledButton {
                    buttonStyle: ({
                            "color": d.selectedConfig === modelData ? root.selectedProfileColor : root.labelBackgroundColor
                        })
                    radius: Units.pt(3)
                    text: modelData

                    onClicked: {
                        d.userSelected = true;
                        d.selectedConfig = modelData;
                    }
                }
            }
        }
        GamepadView {
            Layout.fillHeight: true
            Layout.fillWidth: true
            accentColor: Style.colors.status.info
            contentColor: Style.getTextColor(root.labelBackgroundColor)
            controlLabels: d.controlLabels
            labelBackgroundColor: root.labelBackgroundColor
            reservedControls: d.reservedControls
        }
    }
}
