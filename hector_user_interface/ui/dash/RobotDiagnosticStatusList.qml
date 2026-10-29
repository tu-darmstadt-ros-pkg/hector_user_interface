import QtQuick 2.3
import QtQuick.Controls 2.1
import QtQuick.Layouts 1.1
import Ros2 1.0
import Hector.Controls 1.0
import Hector.InternalControls 1.0
import Hector.Utils 1.0
import Hector.Style 1.0
import Hector.MultiRobot 1.0

Dialog {
    id: root

    property var components_lm: ListModel {
        id: componentsListModel
    }
    property var computer_monitor_lm: ListModel {
        id: computerMonitorListModel
    }
    property var nodes_lm: ListModel {
        id: nodesListModel
    }
    property var others_lm: ListModel {
        id: othersListModel
    }
    property var sensor_monitor_lm: ListModel {
        id: sensorMonitorListModel
    }
    property var tf_tree_lm: ListModel {
        id: tfTreeListModel
    }
    property var topics_lm: ListModel {
        id: topicsListModel
    }

    // Function to get status index by its name
    function find(model, criteria) {
        for (var i = 0; i < model.count; ++i)
            if (criteria(model.get(i)))
                return i;
        return null;
    }
    function getTopLevel(model) {
        let res = 0;
        for (let i = 0; i < model.count; i++) {
            res = Math.max(res, model.get(i).level);
        }
        return res;
    }

    Subscription {
        id: diagnosticAggSubscriber
        topic: RobotManager.activeRobot.namespace + "/diagnostics_agg"

        onNewMessage: {
            if (!root.visible)
                return; // No need to process messages if dialog is not visible
            let components_tmp = [];
            let computer_monitor_tmp = [];
            let sensor_monitor_tmp = [];
            let nodes_tmp = [];
            let topics_tmp = [];
            let tf_tree_tmp = [];
            let others_tmp = [];

            // Store items in temporary arrays
            for (var i = 0; i < diagnosticAggSubscriber.message.status.length; i++) {
                let status = diagnosticAggSubscriber.message.status.at(i);
                if (status.name.startsWith("/Software Monitor/Components")) {
                    if (status.name !== "/Software Monitor/Components") // Skip header message
                        components_tmp.push(status);
                } else if (status.name.startsWith("/Software Monitor/Active Nodes")) {
                    if (status.name !== "/Software Monitor/Active Nodes")
                        nodes_tmp.push(status);
                } else if (status.name.startsWith("/Software Monitor/Active Topics")) {
                    if (status.name !== "/Software Monitor/Active Topics")
                        topics_tmp.push(status);
                } else if (status.name.startsWith("/Software Monitor/TF Tree")) {
                    if (status.name !== "/Software Monitor/TF Tree")
                        tf_tree_tmp.push(status);
                } else if (status.name.startsWith("/Computer Monitor")) {
                    if (status.name !== "/Computer Monitor")
                        computer_monitor_tmp.push(status);
                } else if (status.name.startsWith("/Sensor Monitor")) {
                    if (status.name !== "/Sensor Monitor")
                        sensor_monitor_tmp.push(status);
                } else {
                    if (status.name === "/Software Monitor" || status.name === "/Other")
                        continue;
                    others_tmp.push(status);
                }
            }

            // Sort arrays
            components_tmp.sort();
            computer_monitor_tmp.sort();
            sensor_monitor_tmp.sort();
            nodes_tmp.sort();
            topics_tmp.sort();
            tf_tree_tmp.sort();
            others_tmp.sort();

            // Update ListModels

            // Components
            components_lm.clear();
            for (let j = 0; j < components_tmp.length; j++) {
                let status = components_tmp[j];
                let parts = status.name.split("/");
                // ['', 'Software Monitor', 'Components', manager, component]
                if (parts.length < 5)
                    continue;
                let componentName = parts[4];

                // Insert component
                components_lm.append({
                        "type": "component",
                        "name": componentName,
                        "level": status.level,
                        "message": status.message,
                        "manager": status.hardware_id
                    });
            }

            // Nodes
            for (let j = 0; j < nodes_tmp.length; j++) {
                let values = {};
                let nodeValues = nodes_tmp[j].values.toArray();
                for (let l = 0; l < nodeValues.length; l++)
                    values[nodeValues[l].key] = nodeValues[l].value;
                let status_tmp = {
                    "name": nodes_tmp[j].name,
                    "message": nodes_tmp[j].message,
                    "level": nodes_tmp[j].level,
                    "values": values
                };
                let idx = find(nodes_lm, function (item) {
                        return item.name === nodes_tmp[j].name;
                    });
                if (idx === null)
                    nodes_lm.append(status_tmp);
                else
                    nodes_lm.set(idx, status_tmp);
            }

            // Topics
            for (let j = 0; j < topics_tmp.length; j++) {
                let values = {};
                let topicValues = topics_tmp[j].values.toArray();
                for (let l = 0; l < topicValues.length; l++)
                    values[topicValues[l].key] = topicValues[l].value;
                let status_tmp = {
                    "name": topics_tmp[j].name,
                    "message": topics_tmp[j].message,
                    "level": topics_tmp[j].level,
                    "values": values
                };
                let idx = find(topics_lm, function (item) {
                        return item.name === topics_tmp[j].name;
                    });
                if (idx === null)
                    topics_lm.append(status_tmp);
                else
                    topics_lm.set(idx, status_tmp);
            }

            // TF Tree
            for (let j = 0; j < tf_tree_tmp.length; j++) {
                let values = {};
                let tfValues = tf_tree_tmp[j].values.toArray();
                for (let l = 0; l < tfValues.length; l++)
                    values[tfValues[l].key] = tfValues[l].value;
                let status_tmp = {
                    "name": tf_tree_tmp[j].name,
                    "message": tf_tree_tmp[j].message,
                    "level": tf_tree_tmp[j].level,
                    "values": values
                };
                let idx = find(tf_tree_lm, function (item) {
                        return item.name === tf_tree_tmp[j].name;
                    });
                if (idx === null)
                    tf_tree_lm.append(status_tmp);
                else
                    tf_tree_lm.set(idx, status_tmp);
            }

            // Computer Monitor
            for (let j = 0; j < computer_monitor_tmp.length; j++) {
                // Clip namespace
                computer_monitor_tmp[j].name = computer_monitor_tmp[j].name.replace("/Computer Monitor/", "");
                let values = {};
                let computerValues = computer_monitor_tmp[j].values.toArray();
                for (let l = 0; l < computerValues.length; l++)
                    values[computerValues[l].key] = computerValues[l].value;
                let status_tmp = {
                    "name": computer_monitor_tmp[j].name,
                    "message": computer_monitor_tmp[j].message,
                    "level": computer_monitor_tmp[j].level,
                    "values": values
                };
                let idx = find(computer_monitor_lm, function (item) {
                        return item.name === computer_monitor_tmp[j].name;
                    });
                if (idx === null)
                    computer_monitor_lm.append(status_tmp);
                else
                    computer_monitor_lm.set(idx, status_tmp);
            }

            // Sensor Monitor
            for (let j = 0; j < sensor_monitor_tmp.length; j++) {
                // Clip namespace
                sensor_monitor_tmp[j].name = sensor_monitor_tmp[j].name.replace("/Sensor Monitor/", "");
                let values = {};
                let sensorValues = sensor_monitor_tmp[j].values.toArray();
                for (let l = 0; l < sensorValues.length; l++)
                    values[sensorValues[l].key] = sensorValues[l].value;
                let status_tmp = {
                    "name": sensor_monitor_tmp[j].name,
                    "message": sensor_monitor_tmp[j].message,
                    "level": sensor_monitor_tmp[j].level,
                    "values": values
                };
                let idx = find(sensor_monitor_lm, function (item) {
                        return item.name === sensor_monitor_tmp[j].name;
                    });
                if (idx === null)
                    sensor_monitor_lm.append(status_tmp);
                else
                    sensor_monitor_lm.set(idx, status_tmp);
            }

            // Others
            for (let j = 0; j < others_tmp.length; j++) {
                let values = {};
                let othersValues = others_tmp[j].values.toArray();
                for (let l = 0; l < othersValues.length; l++)
                    values[othersValues[l].key] = othersValues[l].value;
                let status_tmp = {
                    "name": others_tmp[j].name,
                    "message": others_tmp[j].message,
                    "level": others_tmp[j].level,
                    "values": values
                };
                let idx = find(others_lm, function (item) {
                        return item.name === others_tmp[j].name;
                    });
                if (idx === null)
                    others_lm.append(status_tmp);
                else
                    others_lm.set(idx, status_tmp);
            }
        }
    }
    GridLayout {
        id: grid
        anchors.fill: parent

        DiagnosticStatus {
            Layout.column: 0
            Layout.fillWidth: true
            Layout.row: 0
            header: true
            level: getTopLevel(componentsListModel)
            name: "Components"
        }
        ListView {
            id: componentsList
            Layout.column: 0
            Layout.fillHeight: true
            Layout.fillWidth: true
            Layout.row: 1
            model: componentsListModel
            spacing: Units.pt(5)

            delegate: DiagnosticStatus {
                property variant myData: model

                header: false
                level: model.level
                name: model.name
                width: componentsList.width
            }
        }
        DiagnosticStatus {
            Layout.column: 1
            Layout.fillWidth: true
            Layout.row: 0
            header: true
            level: getTopLevel(nodesListModel)
            name: "Nodes"
        }
        ListView {
            id: nodesList
            Layout.column: 1
            Layout.fillHeight: true
            Layout.fillWidth: true
            Layout.row: 1
            model: nodesListModel
            spacing: Units.pt(5)

            delegate: DiagnosticStatus {
                property variant myData: model

                level: model.level
                name: model.values["node"]
                width: nodesList.width
            }
        }
        DiagnosticStatus {
            Layout.column: 2
            Layout.fillWidth: true
            Layout.row: 0
            header: true
            level: getTopLevel(topicsListModel)
            name: "Topics"
        }
        ListView {
            id: topicsList
            Layout.column: 2
            Layout.fillHeight: true
            Layout.fillWidth: true
            Layout.row: 1
            model: topicsListModel
            spacing: Units.pt(5)

            delegate: DiagnosticStatus {
                property variant myData: model

                level: model.level
                message: model.level ? model.message : ""
                name: model.values["topic"]
                width: topicsList.width
            }
        }
        DiagnosticStatus {
            Layout.column: 3
            Layout.fillWidth: true
            Layout.row: 0
            header: true
            level: getTopLevel(tfTreeListModel)
            name: "TF Tree"
        }
        ListView {
            id: tftreeList
            Layout.column: 3
            Layout.fillHeight: true
            Layout.fillWidth: true
            Layout.row: 1
            model: tfTreeListModel
            spacing: Units.pt(5)

            delegate: DiagnosticStatus {
                property variant myData: model

                level: model.level
                name: model.values["source frame"] + " -> " + model.values["target frame"]
                width: tftreeList.width
            }
        }
        DiagnosticStatus {
            Layout.column: 4
            Layout.fillWidth: true
            Layout.row: 0
            header: true
            level: getTopLevel(computerMonitorListModel)
            name: "Computer Monitor"
        }
        ListView {
            id: computerMonitorList
            Layout.column: 4
            Layout.fillHeight: true
            Layout.fillWidth: true
            Layout.row: 1
            model: computerMonitorListModel
            spacing: Units.pt(5)

            delegate: DiagnosticStatus {
                property variant myData: model

                level: model.level
                message: model.level ? model.message : ""
                name: model.name
                width: computerMonitorList.width
            }
        }
        DiagnosticStatus {
            Layout.column: 5
            Layout.fillWidth: true
            Layout.row: 0
            header: true
            level: getTopLevel(sensorMonitorListModel)
            name: "Sensor Monitor"
        }
        ListView {
            id: sensorMonitorList
            Layout.column: 5
            Layout.fillHeight: true
            Layout.fillWidth: true
            Layout.row: 1
            model: sensorMonitorListModel
            spacing: Units.pt(5)

            delegate: DiagnosticStatus {
                property variant myData: model

                level: model.level
                message: model.level ? model.message : ""
                name: model.name
                width: sensorMonitorList.width
            }
        }
        DiagnosticStatus {
            Layout.column: 6
            Layout.fillWidth: true
            Layout.row: 0
            header: true
            level: getTopLevel(othersListModel)
            name: "Others"
        }
        ListView {
            id: othersList
            Layout.column: 6
            Layout.fillHeight: true
            Layout.fillWidth: true
            Layout.row: 1
            model: othersListModel
            spacing: Units.pt(5)

            delegate: DiagnosticStatus {
                property variant myData: model

                level: model.level
                message: model.level ? model.message : ""
                name: model.name.replace("/Other", "")
                width: othersList.width
            }
        }
    }
}
