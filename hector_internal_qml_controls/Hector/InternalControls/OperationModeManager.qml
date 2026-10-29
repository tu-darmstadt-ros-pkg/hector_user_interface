pragma Singleton
import QtQuick 2.0
import Hector.Utils 1.0
import Hector.MultiRobot 1.0
import Ros2 1.0

Object {
    enum OperationMode {
        Unknown,
        Safe,
        Teleoperation,
        Manipulation,
        Autonomous
    }

    readonly property int activeMode: {
        if (estopSubscriber.anyEStopActive)
            return OperationModeManager.OperationMode.Safe;
        if (joySubscriber.joyProfile == "driving")
            return OperationModeManager.Teleoperation;
        if (joySubscriber.joyProfile == "manipulation")
            return OperationModeManager.Manipulation;
        return OperationModeManager.Unknown;
    }

    Subscription {
        id: joySubscriber

        property string joyProfile: message && message.data || "driving"

        topic: "/" + OcsManager.namespace + "/joy_teleop_profile"
    }
    Subscription {
        id: estopSubscriber

        property bool anyEStopActive: {
            if (!message)
                return false;
            for (let i = 0; i < message.values.length; ++i) {
                if (message.values.at(i))
                    return true;
            }
            return false;
        }

        topic: RobotManager.activeRobot ? RobotManager.activeRobot.namespace + "/e_stop_manager/e_stop_list" : ""
    }
}
