.pragma library

// Returns the rviz display class id for a parsed visualization, or null if unsupported.
function classIdFor(viz) {
  switch (viz.messageType) {
    case "map_bag_msgs/msg/MapBag": return "map_bag_rviz_plugin/MapBag"
    case "nav_msgs/msg/Path": return "rviz_default_plugins/Path"
    case "sensor_msgs/msg/PointCloud2": return "hector_rviz_plugins/PointCloudFilter"
    case "visualization_msgs/msg/Marker": return "rviz_default_plugins/Marker"
    case "visualization_msgs/msg/MarkerArray": return "rviz_default_plugins/MarkerArray"
    default: return null
  }
}

// MapBag's topic is a plain "Topic" string property; Display::setTopic is a no-op for it.
function usesTopicProperty(viz) {
  return viz.messageType === "map_bag_msgs/msg/MapBag"
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
