.pragma library

// Returns the rviz display class id for a parsed visualization, or null if unsupported.
function classIdFor(viz) {
  switch (viz.messageType) {
    case "hector_robot_pose_preview_msgs/msg/PosePreview": return "hector_robot_pose_preview_rviz/PosePreview"
    case "map_bag_msgs/msg/MapBag": return "map_bag_rviz_plugin/MapBag"
    case "moveit_msgs/msg/DisplayRobotState": return "moveit_rviz_plugin/RobotState"
    case "nav_msgs/msg/Path": return "rviz_default_plugins/Path"
    case "sensor_msgs/msg/PointCloud2": return "hector_rviz_plugins/PointCloudFilter"
    case "visualization_msgs/msg/Marker": return "rviz_default_plugins/Marker"
    case "visualization_msgs/msg/MarkerArray": return "rviz_default_plugins/MarkerArray"
    default: return null
  }
}

// Some displays can't have their topic set the usual way. For those, returns the name of the
// setting that holds the topic instead. Returns null for all other displays.
function topicPropertyFor(viz) {
  switch (viz.messageType) {
    case "hector_robot_pose_preview_msgs/msg/PosePreview": return "Topic"
    case "map_bag_msgs/msg/MapBag": return "Topic"
    case "moveit_msgs/msg/DisplayRobotState": return "Robot State Topic"
    default: return null
  }
}

function tfPropertiesFor(viz, robot, uiNamespace) {
  let local = robot.namespace === uiNamespace
  switch (viz.messageType) {
    case "hector_robot_pose_preview_msgs/msg/PosePreview":
      return { "TF Prefix": local ? "" : robot.tfPrefix }
    case "sensor_msgs/msg/PointCloud2":
      // The point cloud is filtered relative to the robot's base frame, written the way the UI expects
      if (!robot.baseFrame)
        return {}
      return { "Filter/Frame": local ? robot.baseFrame.substring(robot.tfPrefix.length) : robot.baseFrame }
    default: return {}
  }
}

// Returns the topic to display for a parsed visualization of robot. A UI in the robot's namespace
// uses the robot-local tf tree, so it shows the original topic. Elsewhere the global tf tree with
// prefixed frames applies, so a topic inside the robot namespace maps to its forwarded copy in
// <namespace>/world if that is among topics (only forwarded topics have one). Otherwise, and for
// topics outside the robot namespace, the original topic is used.
function displayTopic(viz, robot, uiNamespace, topics) {
  if (robot.namespace === uiNamespace || !viz.topic.startsWith(robot.namespace + "/"))
    return viz.topic
  let worldTopic = robot.namespace + "/world" + viz.topic.substring(robot.namespace.length)
  return topics.indexOf(worldTopic) !== -1 ? worldTopic : viz.topic
}
