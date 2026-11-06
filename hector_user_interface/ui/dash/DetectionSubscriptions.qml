import QtQml
import QtQuick
import Ros2
import Hector.Utils

//! One subscription per 2D detection topic, shared by all camera overlays.
//! A topic is only subscribed while it is acquired by at least one overlay.
NonVisualItem {
    id: root

    property bool active: true
    readonly property string messageType: "hector_perception_msgs/msg/ObjectDetection2DArray"
    //! The sorted detection topics, only reassigned on changes.
    property var topics: []

    function acquire(topic) {
        d.users[topic] = (d.users[topic] || 0) + 1;
        if (d.users[topic] > 1)
            return;
        d.subscriptions[topic] = subscriptionComponent.createObject(root, {
            "topic": topic
        });
        d.revision++;
    }
    function refresh() {
        const topics = Array.from(Ros2.queryTopics(messageType)).sort();
        if (JSON.stringify(topics) !== JSON.stringify(root.topics))
            root.topics = topics;
    }
    function release(topic) {
        if (!d.users[topic] || --d.users[topic] > 0)
            return;
        delete d.users[topic];
        d.subscriptions[topic].destroy();
        delete d.subscriptions[topic];
        d.revision++;
    }
    //! The Subscription of the given topic, null if it is not acquired.
    function subscription(topic) {
        d.revision;
        return d.subscriptions[topic] || null;
    }

    QtObject {
        id: d

        property int revision: 0
        property var subscriptions: ({})
        property var users: ({})
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
