import QtQuick 2.3
import Hector.Utils 1.0
import Ros2 1.0

//! Live value of a single announced sensor: subscribes to the sensor's topic and its optional warn
//! topic and exposes the formatted value together with its stale, warn and danger state.
//! Non-visual, the presentation is left to the user of this item.
NonVisualItem {
    id: control

    readonly property bool dangerous: crossesThreshold("danger_above", "danger_below")
    //! Fallback stale timeout (ms) when a sensor announces no "timeout" hint.
    property int defaultTimeout: 5000
    //! Set to false to drop the subscriptions, e.g. while the display is hidden.
    property bool enabled: true

    //! Last received message, null before the first one.
    property var message: null

    //! Announced sensor as parsed by RobotManager:
    //! { id, name, topic, messageType, field, unit, icon, prefix, warnTopic, hints }
    property var sensor: null
    //! True while no message arrived within the sensor's timeout.
    property bool stale: true
    readonly property bool subscribed: sensorSubscription.subscribed
    //! The value, formatted and prefixed as announced. "?" while stale or before the first message.
    readonly property string text: {
        if (!sensor)
            return "";
        if (stale || message === null)
            return sensor.prefix + "?";
        return sensor.prefix + formatValue(value, sensor.hints);
    }
    //! Milliseconds without a new message after which the value goes stale, 0 to never go stale.
    readonly property int timeout: sensor && sensor.hints.timeout !== undefined ? parseFloat(sensor.hints.timeout) * 1000 : defaultTimeout
    //! The sensor's field value, undefined before the first message.
    readonly property var value: sensor && message !== null ? getFieldValue(message, sensor.field) : undefined
    readonly property bool warn: warnSubscription.active || crossesThreshold("warn_above", "warn_below")

    //! True when the current value crosses one of the given threshold hints. Numeric-only; string
    //! fields never trigger thresholds.
    function crossesThreshold(aboveKey, belowKey) {
        if (typeof value !== "number")
            return false;
        let hints = sensor.hints;
        if (hints[aboveKey] !== undefined && value > parseFloat(hints[aboveKey]))
            return true;
        if (hints[belowKey] !== undefined && value < parseFloat(hints[belowKey]))
            return true;
        return false;
    }

    //! Formats a raw field value. Numbers honor the "decimals" hint (raw JS string when absent);
    //! everything else is shown as-is. Missing values show "?".
    function formatValue(raw, hints) {
        if (raw === undefined || raw === null)
            return "?";
        if (typeof raw === "number" && hints.decimals !== undefined) {
            let decimals = parseInt(hints.decimals);
            if (!isNaN(decimals))
                return raw.toFixed(decimals);
        }
        return "" + raw;
    }

    //! Dotted-path member access, e.g. "deduction_status.mode.name". Returns undefined if any segment
    //! is missing; an empty field returns the whole message.
    function getFieldValue(message, field) {
        if (!field)
            return message;
        let value = message;
        let parts = field.split(".");
        for (let i = 0; i < parts.length && value !== undefined && value !== null; ++i) {
            value = value[parts[i]];
        }
        return value;
    }

    onSensorChanged: {
        message = null;
        stale = true;
        staleTimer.stop();
    }

    Subscription {
        id: sensorSubscription
        enabled: control.enabled && !!control.sensor
        messageType: control.sensor ? control.sensor.messageType : ""
        topic: control.sensor ? control.sensor.topic : ""

        onNewMessage: function (message) {
            control.message = message;
            control.stale = false;
            if (control.timeout > 0)
                staleTimer.restart();
        }
    }

    // Optional separate boolean topic that drives the warn state.
    Subscription {
        id: warnSubscription

        property bool active: warnSubscription.message ? !!warnSubscription.message.data : false

        enabled: control.enabled && !!control.sensor && control.sensor.warnTopic !== ""
        topic: control.sensor ? control.sensor.warnTopic : ""
    }

    // Restarted by every message, so it only fires once the sensor went quiet for its timeout.
    Timer {
        id: staleTimer
        interval: control.timeout

        onTriggered: control.stale = true
    }
}
