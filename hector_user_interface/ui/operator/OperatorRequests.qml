import QtQuick 2.8
import QtQuick.Controls.Basic 2.2
import Ros2 1.0
import Hector.Style 1.0
import Hector.Utils 1.0

// Hosts the OperatorPrompt action server, keeps the pending requests, and renders
// them as a bottom-right stack (non-modal) and a centered modal popup (modal).
// All state mutation happens on the GUI thread (onGoalAccepted / operator callbacks
// / timer / cancelRequested), so no marshalling is needed.
Item {
    id: root

    // Vertical space to leave free at the bottom for the dash (+ waypoint controls).
    // Computed by the parent from its own ids; the card stack sits above it.
    property real bottomInset: 0

    // Newest-first so the BottomToTop ListView puts the newest card nearest the dash
    // and clips the oldest at the top when the stack overflows.
    property var cardRequests: requests.filter(function (r) {
            return !r.modal;
        }).reverse()
    property var current: modalRequests.length > 0 ? modalRequests[0] : null
    property var modalRequests: requests.filter(function (r) {
            return r.modal;
        })

    // Shared notifying clock (seconds). The cards bind their countdown to this, so it
    // re-evaluates each tick without mutating the records.
    property real now: Date.now() / 1000

    // Single source of truth. Each record:
    // { goalId, source, severity, modal, dismissable, title, message, options, deadline, handle }
    property var requests: []

    function addRequest(handle) {
        var goal = handle.goal;
        var record = {
            "goalId": handle.goalId,
            "source": goal.source,
            "severity": goal.severity,
            "modal": goal.modal,
            "dismissable": goal.dismissable,
            "title": goal.title,
            "message": goal.message,
            "options": resolveOptions(goal),
            "deadline": goal.timeout > 0 ? Date.now() / 1000 + goal.timeout : 0,
            "handle": handle
        };
        // Fires once the robot's cancel has been accepted and the goal reached canceling.
        handle.cancelRequested.connect(function () {
                finish(handle.goalId, "cancel");
            });
        requests = requests.concat([record]);
    }

    // Single removal path for answer/timeout/dismiss/cancel, both surfaces.
    function finish(goalId, kind, chosenOption) {
        var i = requests.findIndex(function (r) {
                return r.goalId === goalId;
            });
        if (i < 0)
            // already finished
            return;
        var handle = requests[i].handle;
        if (kind === "answer")
            handle.succeed({
                    "outcome": 0,
                    "chosen_option": chosenOption
                });
        else if (kind === "timeout")
            handle.succeed({
                    "outcome": 1,
                    "chosen_option": ""
                });
        else if (kind === "dismiss")
            handle.succeed({
                    "outcome": 2,
                    "chosen_option": ""
                });
        else if (kind === "cancel")
            handle.canceled({
                    "outcome": 2,
                    "chosen_option": ""
                });
        var copy = requests.slice();
        copy.splice(i, 1);
        requests = copy;
    }
    function isValid(goal) {
        if (goal.preset < 0 || goal.preset > 3)
            return false;
        // PRESET_CUSTOM requires at least one option label.
        if (goal.preset === 3 && (!goal.options || goal.options.length === 0))
            return false;
        return true;
    }

    // goal.options is a lazy Array QGadget (length/at/toArray, no .map/[i]); use toArray() first.
    function resolveOptions(goal) {
        switch (goal.preset) {
        case 0 // CONFIRM
        :
            return [{
                    "id": "no",
                    "label": "No",
                    "style": Style.base
                }, {
                    "id": "yes",
                    "label": "Yes",
                    "style": Style.activeStyle
                }];
        case 1 // PROCEED
        :
            return [{
                    "id": "abort",
                    "label": "Abort",
                    "style": Style.base
                }, {
                    "id": "proceed",
                    "label": "Proceed",
                    "style": Style.activeStyle
                }];
        case 2 // ACKNOWLEDGE
        :
            return [{
                    "id": "ok",
                    "label": "OK",
                    "style": Style.activeStyle
                }];
        case 3 // CUSTOM: chosen option is labels, labels may not be duplicated
        :
            return goal.options.toArray().map(function (l, i) {
                    return {
                        "id": l,
                        "label": l,
                        "style": Style.activeStyle
                    };
                });
        }
        return [];
    }

    ActionServer {
        id: server
        // Must be set, else every cancel is rejected by default — withdrawal is the point of the action.
        handleCancel: function (handle) {
            return true;
        }
        // Runs on the GUI thread via BlockingQueuedConnection — keep trivial.
        handleGoal: function (goal, goalId) {
            return root.isValid(goal);
        }
        // Console namespace, static for the UI's lifetime (set at startup in main.qml).
        name: (rviz.namespace === "/" ? "" : rviz.namespace) + "/operator_prompt"
        type: "hector_user_interface_msgs/action/OperatorPrompt"

        onGoalAccepted: function (handle) {
            root.addRequest(handle);
        }
    }

    // One 1 Hz clock for all timeouts.
    Timer {
        interval: 1000
        repeat: true
        running: root.requests.length > 0

        onTriggered: {
            root.now = Date.now() / 1000;
            // Collect first, then finish — finish reassigns requests.
            var expired = [];
            for (var i = 0; i < root.requests.length; ++i) {
                var r = root.requests[i];
                if (r.deadline > 0 && root.now >= r.deadline)
                    expired.push(r.goalId);
            }
            for (var j = 0; j < expired.length; ++j)
                root.finish(expired[j], "timeout");
        }
    }

    // --- Non-modal stack: bottom-right, above the dash, capped and clipped. ---
    ListView {
        id: cardStack
        anchors.bottom: parent.bottom
        anchors.bottomMargin: root.bottomInset
        anchors.right: parent.right
        anchors.rightMargin: Units.pt(4)
        clip: true
        height: Math.min(contentHeight, Units.pt(400))
        interactive: false
        model: root.cardRequests
        spacing: Units.pt(4)
        // index 0 (newest) pinned to the bottom; overflow clips the oldest at the top.
        verticalLayoutDirection: ListView.BottomToTop
        width: Units.pt(360)
        z: 100

        add: Transition {
            NumberAnimation {
                duration: 150
                from: 0
                property: "opacity"
                to: 1
            }
        }
        delegate: OperatorRequestCard {
            deadline: modelData.deadline
            dismissable: modelData.dismissable
            message: modelData.message
            now: root.now
            options: modelData.options
            severity: modelData.severity
            source: modelData.source
            title: modelData.title
            width: ListView.view.width

            onAnswered: function (id) {
                root.finish(modelData.goalId, "answer", id);
            }
            onDismissed: function () {
                root.finish(modelData.goalId, "dismiss");
            }
        }
        displaced: Transition {
            NumberAnimation {
                duration: 200
                properties: "x,y"
            }
        }
    }

    // --- Modal: scrim + centered card, plain anchored (no Dialog / overlay attachment). ---
    Rectangle {
        id: scrim
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.5)
        visible: root.current !== null
        z: 100

        // Swallow everything so nothing reaches the cards or RViz behind it.
        MouseArea {
            acceptedButtons: Qt.AllButtons
            anchors.fill: parent

            onWheel: function (wheel) { wheel.accepted = true }
        }
    }
    OperatorRequestCard {
        id: modalCard
        anchors.centerIn: parent
        deadline: root.current ? root.current.deadline : 0
        dismissable: root.current ? root.current.dismissable : false
        message: root.current ? root.current.message : ""
        now: root.now
        options: root.current ? root.current.options : []
        severity: root.current ? root.current.severity : 0
        source: root.current ? root.current.source : ""
        title: root.current ? root.current.title : ""
        visible: root.current !== null
        z: 100

        onAnswered: function (option) {
            if (root.current)
                root.finish(root.current.goalId, "answer", option);
        }
        onDismissed: function () {
            if (root.current)
                root.finish(root.current.goalId, "dismiss");
        }
    }
}
