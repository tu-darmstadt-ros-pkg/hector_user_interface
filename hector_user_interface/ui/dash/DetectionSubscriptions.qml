import QtQml
import QtQuick
import Ros2
import Hector.Utils

//! One subscription per 2D detection topic, shared by all camera overlays.
//! Subscriptions are managed by topic so that new topics do not recreate the existing ones.
NonVisualItem {
    id: root

    property bool active: true
    readonly property string messageType: "hector_perception_msgs/msg/ObjectDetection2DArray"
    //! The sorted detection topics, only reassigned on changes.
    property var topics: []

    function refresh() {
        const topics = Array.from(Ros2.queryTopics(messageType)).sort();
        if (JSON.stringify(topics) === JSON.stringify(root.topics))
            return;
        for (const topic of topics) {
            if (!d.subscriptions[topic])
                d.subscriptions[topic] = subscriptionComponent.createObject(root, {
                    "topic": topic
                });
        }
        for (const topic in d.subscriptions) {
            if (topics.includes(topic))
                continue;
            d.subscriptions[topic].destroy();
            delete d.subscriptions[topic];
        }
        root.topics = topics;
    }
    //! The Subscription of the given topic, null if it is not in topics.
    function subscription(topic) {
        root.topics; // Re-evaluate bindings when subscriptions are added or removed.
        return d.subscriptions[topic] || null;
    }

    QtObject {
        id: d

        property var subscriptions: ({})
    }
    Component {
        id: subscriptionComponent

        Subscription {
            enabled: root.active
            messageType: root.messageType
        }
    }
    Timer {
        interval: 5000
        repeat: true
        running: root.active
        triggeredOnStart: true

        onTriggered: root.refresh()
    }
}
