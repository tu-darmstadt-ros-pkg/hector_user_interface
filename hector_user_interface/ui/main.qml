import QtQuick 2.8
import QtQuick.Controls.Basic 2.2
import Ros2 1.0
import Hector.Controls 1.0
import Hector.Utils 1.0
import Hector.MultiRobot 1.0

Item {
    id: appWindow

    property bool initialized: false

    anchors.fill: parent

    Component.onCompleted: {
        // Init if not initialized
        if (!Ros2.isInitialized()) {
            console.log("Ros was not initialized. Initializing.");
            let namespace = rviz && (rviz.nodeName + "_") || "";
            let initOptions = Ros2.createInitOptions();
            initOptions.setNamespace(rviz.namespace);
            Ros2.init(namespace + "hector_user_interface", initOptions);
        }
        if (rviz.namespace != "") {
            Ros2.info("Started UI in namespace: " + rviz.namespace);
            Ros2.info("Waiting for robot...");
        }
        // When reloading, the singletons will preserve state, so we have to
        // check if the robot is already active
        if (RobotManager.activeRobot != null) {
            interfaceComponent.createObject(appWindow);
            appWindow.initialized = true;
        }
        // for (let action of rviz.config.robotActions.actions) {
        //   RobotActionManager.registerAction(action)
        // }
    }

    Connections {
        function onActiveRobotChanged() {
            if (appWindow.initialized)
                return;
            if (RobotManager.activeRobot != null) {
                interfaceComponent.createObject(appWindow);
                appWindow.initialized = true;
            }
        }

        target: RobotManager
    }
    SplashScreen {
        id: splashScreen
        anchors.fill: parent
        visible: RobotManager.activeRobot == null || !RobotManager.activeRobot.isReady
        z: 1000
    }
    Component {
        id: interfaceComponent
        RobotInterface {
            id: robotInterface
            anchors.fill: parent
        }
    }
}
