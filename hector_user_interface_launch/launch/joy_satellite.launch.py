from launch import LaunchDescription
from launch.actions import DeclareLaunchArgument, GroupAction, IncludeLaunchDescription
from launch.substitutions import LaunchConfiguration, PathJoinSubstitution
from launch_ros.actions import PushRosNamespace
from launch_ros.substitutions import FindPackageShare
import re
import socket


def generate_launch_description():
    """Operator-station joystick stack: the joy driver plus the joy satellite that
    forwards the local gamepad to the active robot. The robot-side gamepad manager
    (which needs a per-robot plugin config) is launched on the robot, not here."""
    ld = LaunchDescription()

    declare_arg_device = DeclareLaunchArgument(
        name="device_name", default_value="", description="Path to the joystick device"
    )
    ld.add_action(declare_arg_device)
    device_name = LaunchConfiguration("device_name")

    declare_arg_robot_namespace = DeclareLaunchArgument(
        name="robot_namespace",
        default_value="",
        description="Robot namespace the gamepad initially forwards to (empty = none)",
    )
    ld.add_action(declare_arg_robot_namespace)
    robot_namespace = LaunchConfiguration("robot_namespace")

    # Operator control station namespace, derived from the hostname so multiple
    # operators can run independent joy stacks. Mirrors sanitizeTopic in
    # hector_qml_controls/Hector/Utils/rosutils.js (used by OcsManager.namespace).
    hostname_sanitized = re.sub(r"[^a-zA-Z0-9_]", "_", socket.gethostname())
    if not hostname_sanitized[0].isalpha():
        hostname_sanitized = "ns" + hostname_sanitized

    # Joy driver and satellite both live in the OCS namespace: the satellite's relative
    # joy/feedback topics line up with the driver and its set_target_robot service is
    # reachable at /<ocs>/set_target_robot (the namespace the UI's OcsManager uses).
    ld.add_action(
        GroupAction(
            actions=[
                PushRosNamespace(hostname_sanitized + "/joy_satellite"),
                IncludeLaunchDescription(
                    PathJoinSubstitution([
                        FindPackageShare("hector_user_interface_launch"),
                        "launch",
                        "joy_node.launch.yaml",
                    ]),
                    launch_arguments={"device_name": device_name}.items(),
                ),
                IncludeLaunchDescription(
                    PathJoinSubstitution([
                        FindPackageShare("hector_gamepad_manager"),
                        "launch",
                        "joy_satellite.launch.yaml",
                    ]),
                    launch_arguments={"target_robot": robot_namespace}.items(),
                ),
            ]
        )
    )

    return ld
