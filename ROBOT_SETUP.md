# Robot Setup

The Hector User Interface automatically discovers and integrates new robots.
To enable this, they have to follow some conventions:

- **Topics**: Each robot should namespace their topics.
  E.g. for athena, every topic is under `/athena/{topic}` (`/athena/tf`, `/athena/cmd_vel`, ...)
  - `imu`: The IMU should be published on `/{robot}/imu` so for tracked or wheeled the orientation (roll / pitch) can be shown.
- **Tf Tree**: Each robot should publish their tf on the global tf topic with the namespace as prefix to isolate
  the tf trees, e.g. using a forwarder (such as [hector_multi_robot](https://github.com/tu-darmstadt-ros-pkg/hector_multi_robot))
  - The robot's base link should be called `base_link` for the view controller.
  A global `world` frame is used and needs transforms to each robot map frame (e.g. `athena/map`).
- **Visualizations**: Since the global tf tree uses prefixed frames, visualizations need to also use prefixed frame names.
  The convention for such visualization topics is to use a world subnamespace, e.g. `/athena/world/point_cloud`.
  The advertised visualization is just `point_cloud`, if the UI is started in the robot namespace, it will subscribe to
  `/athena/point_cloud` and in the global namespace / without one, it will use `/athena/world/point_cloud`.
  hector_multi_robot also provides a topic forwarder that can add the prefix to all `frame_id` fields.
- **Sensors**: Also announced in the robot announcement and will dynamically be added.
  E.g. to visualize velocity, gas concentrations, and other single value measurements.
- **Waypoint Navigation**: You need a `/{robot}/navigate_to_pose` action with `nav2_msgs/action/NavigateToPose`.
  The interface will send multiple waypoints as individual goals one after the other.

## Additional Packages

The following packages can help you integrate your robot in the user interface.

### Emergency Stop Manager

Our robots have multiple E-Stops, and the user interface also has one.
You can use our [e_stop_manager](https://github.com/tu-darmstadt-ros-pkg/e_stop_manager) or
implement the interfaces so the UI can display the state of the E-Stops and also
toggle the UI E-Stop.

> [!NOTE]
> If you are looking for a cheap e-stop solution to safely test your robot check out our
> [Open-Hardware E-Stop](https://github.com/tu-darmstadt-ros-pkg/athena/tree/main/E-Stop)
> released as part of our [Open-Hardware Robot Athena](https://github.com/tu-darmstadt-ros-pkg/athena).

### Gamepad Manager

The UI comes with a joy satellite node that forwards the commands from the connected joystick
to the currently selected robot publishing on `/<selected robot>/joy`.
If you use the [hector_gamepad_manager](https://github.com/tu-darmstadt-ros-pkg/hector_gamepad_manager) to control your robot, the UI can connect to it and also display
the gamepad configuration if you click on the currently active gamepad configuration in the dash
below the orientation view.

### Hector Multi Robot

To announce your robot for discovery by the user interface, you can use the [hector_multi_robot package](https://github.com/tu-darmstadt-ros-pkg/hector_multi_robot).
It provides a simple announcer node which can be configured with provided visualizations, frames to forward, battery information and more.
The interface uses the announcement message on `/robot_announcement` to discover the available robots and reconfigure the interface to add their visualizations.

### ROS Camera Server

In limited bandwidth environments, degraded network conditions, or simply always really, you should use efficient codecs for live operator video feeds.
The user interface uses the `/camera_server_announcement` from [ROS Camera Server](https://github.com/StefanFabian/ros_camera_server) to discover
available camera streams.

The ROS Camera Server enables you to declare your cameras using a simple yaml configuration with multiple supported inputs and the outputs you need,
e.g. ROS images for software and WebRTC / SRT streams for the operator. Multiple outputs per camera can be specified with individual resolution
and framerate, and the camera server will automatically build and monitor pipelines.
The available cameras are advertised and discovered by the user interface.
