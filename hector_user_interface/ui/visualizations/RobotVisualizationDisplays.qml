import QtQuick 2.3
import Ros2 1.0
import Hector.MultiRobot 1.0
import Hector.Utils 1.0
import "VisualizationTypes.js" as VisualizationTypes

//! Owns one rviz display group named after the robot and one display per
//! supported announced visualization. Display visibility follows the robot's
//! visualizationModes and the active robot.
NonVisualItem {
    id: root

    property Robot robot

    Component.onCompleted: d.sync()
    Component.onDestruction: {
        if (d.group && d.group.valid)
            rviz.displayManager.removeDisplay(d.group);
    }

    QtObject {
        id: d

        // viz.name -> the viz.key whose configuration was last written to the display.
        // Configuration is (re)applied only when this differs, so redundant
        // re-announcements do not overwrite operator edits made in the rviz panel.
        property var appliedKeyByName: ({})
        // viz.name -> the topic last set on the display, see VisualizationTypes.displayTopic().
        property var appliedTopicByName: ({})
        // viz.name -> display wrapper. Kept in a JS map since the wrappers are
        // QObjects and must not carry ad-hoc properties. Names are the identity rviz
        // uses for displays within a group and are enforced unique per robot in sync().
        property var displaysByName: ({})
        property var group: null

        function applyConfiguration(display, viz, topics) {
            // Topic first, some displays create type-dependent sub-properties only after the topic is set
            applyTopic(display, viz, VisualizationTypes.displayTopic(viz, root.robot, rviz.namespace, topics));
            for (let key in viz.hints) {
                if (!key.startsWith("rviz."))
                    continue;
                if (!display.setPropertyValue(key.substring(5), viz.hints[key])) {
                    Ros2.warn("Failed to set property '" + key + "' on display for visualization '" + viz.name + "' (" + d.appliedTopicByName[viz.name] + ")");
                }
            }
        }
        function applyTopic(display, viz, topic) {
            if (VisualizationTypes.usesTopicProperty(viz))
                display.setPropertyValue("Topic", topic);
            else
                display.setTopic(topic, viz.messageType);
            d.appliedTopicByName[viz.name] = topic;
        }
        function makeEnabledBinding(key) {
            return function () {
                let mode = root.robot.visualizationModes[key];
                return mode === Robot.VisualizationMode.On || (mode === Robot.VisualizationMode.WhenActive && RobotManager.activeRobot === root.robot);
            };
        }
        function sync() {
            if (!root.robot)
                return;
            if (!d.group || !d.group.valid) {
                d.group = rviz.displayManager.getDisplay(root.robot.name) || rviz.displayManager.addGroup(root.robot.name);
                d.group.shouldBeSaved = false;
            }

            // Keyed by name, the identity rviz uses for displays within the group.
            // Names must be unique per robot; a collision is surfaced and the duplicate
            // dropped rather than silently overwriting the earlier entry.
            let topics = Ros2.queryTopics();
            let wanted = {};
            for (let viz of root.robot.visualizations) {
                if (!VisualizationTypes.classIdFor(viz))
                    continue;
                if (viz.name in wanted) {
                    Ros2.error("Robot '" + root.robot.name + "' announced duplicate visualization name '" + viz.name + "'; ignoring '" + viz.topic + "' (" + viz.kind + "). Visualization names must be unique per robot.");
                    continue;
                }
                wanted[viz.name] = viz;
            }
            for (let name in d.displaysByName) {
                if (name in wanted)
                    continue;
                let display = d.displaysByName[name];
                if (display.valid)
                    rviz.displayManager.removeDisplay(display);
                delete d.displaysByName[name];
                delete d.appliedKeyByName[name];
                delete d.appliedTopicByName[name];
            }
            for (let name in wanted) {
                let viz = wanted[name];
                let classId = VisualizationTypes.classIdFor(viz);
                let display = d.displaysByName[name];
                let isNew = !display || !display.valid;
                if (isNew) {
                    // rviz's DisplayGroup::save ignores shouldBeSaved and persists our displays,
                    // so a restored config already holds them. Adopt the restored display (matched
                    // by name) instead of creating a duplicate, unless its class no longer matches
                    // the announced kind (a previous session announced this name differently).
                    display = d.group.getDisplay(viz.name);
                    if (display && display.valid && display.classId !== classId) {
                        rviz.displayManager.removeDisplay(display);
                        display = null;
                    }
                    if (!display || !display.valid) {
                        display = rviz.displayManager.addDisplay(d.group, classId, viz.name, false);
                        if (!display) {
                            Ros2.error("Failed to create display for visualization '" + viz.name + "' (" + viz.topic + ")");
                            continue;
                        }
                    }
                    d.displaysByName[name] = display;
                } else if (display.classId !== classId) {
                    // Same name re-announced with a different kind; the display class is fixed
                    // at creation, so the display must be replaced.
                    rviz.displayManager.removeDisplay(display);
                    display = rviz.displayManager.addDisplay(d.group, classId, viz.name, false);
                    if (!display) {
                        Ros2.error("Failed to create display for visualization '" + viz.name + "' (" + viz.topic + ")");
                        delete d.displaysByName[name];
                        delete d.appliedKeyByName[name];
                        delete d.appliedTopicByName[name];
                        continue;
                    }
                    d.displaysByName[name] = display;
                    isNew = true;
                }

                // Apply the announced configuration once per session, and again only when the
                // robot re-announces this display with a different topic or kind (key change).
                // Redundant re-announcements leave operator edits in the rviz panel intact.
                if (isNew || d.appliedKeyByName[name] !== viz.key) {
                    display.shouldBeSaved = false;
                    applyConfiguration(display, viz, topics);
                    d.appliedKeyByName[name] = viz.key;
                }

                // Rebind every sync so visibility keeps following the mode selector and, on a
                // key change, tracks the current mode entry.
                display.enabled = Qt.binding(makeEnabledBinding(viz.key));
            }

            // Drop displays restored from a saved config that are no longer announced so they
            // are neither shown nor re-saved, keeping the group from accumulating on restart.
            // Collect before removing, d.group.displays may be a live list that shifts on removal.
            let stale = [];
            for (let child of d.group.displays) {
                if (child.valid && !(child.name in wanted))
                    stale.push(child);
            }
            for (let child of stale)
                rviz.displayManager.removeDisplay(child);
        }
        //! Switches displays between the original and the forwarded world topic as the latter
        //! appears or disappears. Leaves the rest of the configuration untouched.
        function updateTopics() {
            let topics = Ros2.queryTopics();
            for (let name in d.displaysByName) {
                let display = d.displaysByName[name];
                let viz = root.robot.visualizations.find(v => v.name === name && v.key === d.appliedKeyByName[name]);
                if (!display.valid || !viz)
                    continue;
                let topic = VisualizationTypes.displayTopic(viz, root.robot, rviz.namespace, topics);
                if (topic !== d.appliedTopicByName[name])
                    applyTopic(display, viz, topic);
            }
        }
    }

    // Only a UI outside the robot namespace uses forwarded world topics.
    // TODO: Replace polling with Ros2.graphChanged once the UI moves to qml6_ros2_plugin (Qt6).
    Timer {
        interval: 1000
        repeat: true
        running: !!root.robot && root.robot.namespace !== rviz.namespace

        onTriggered: d.updateTopics()
    }
    Connections {
        function onVisualizationsChanged() {
            d.sync();
        }

        target: root.robot
    }
}
