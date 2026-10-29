//
// Created by Stefan Fabian on 23.03.21.
//

#ifndef HECTOR_USER_INTERFACE_WAYPOINT_TOOL_H
#define HECTOR_USER_INTERFACE_WAYPOINT_TOOL_H

#include "hector_user_interface/waypoint.h"

#include <moveit_ros_visualization/moveit/rviz_plugin_render_tools/robot_state_visualization.hpp>
#include <rviz_default_plugins/tools/interaction/interaction_tool.hpp>
#include <sensor_msgs/msg/joint_state.hpp>
#include <std_msgs/msg/string.hpp>

#include <OgreSharedPtr.h>
#include <QQuaternion>
#include <QVariantMap>
#include <rclcpp/subscription.hpp>

namespace Ogre
{
class SceneNode;
} // namespace Ogre

namespace rviz_common::properties
{
class BoolProperty;
class FloatProperty;
class ColorProperty;
class StringProperty;
class RosTopicProperty;
} // namespace rviz_common::properties

namespace rviz_rendering
{
class ViewportProjectionFinder;
} // namespace rviz_rendering

namespace hector_user_interface
{

class WaypointTool : public rviz_default_plugins::tools::InteractionTool
{
  Q_OBJECT
  Q_PROPERTY( QVariantList waypoints READ waypoints NOTIFY waypointsChanged )
  Q_PROPERTY( QString frame READ frame )
  Q_PROPERTY( QString robotDescriptionTopic READ robotDescriptionTopic WRITE
                  setRobotDescriptionTopic NOTIFY robotDescriptionTopicChanged )
  Q_PROPERTY( QString jointStateTopic READ jointStateTopic WRITE setJointStateTopic NOTIFY
                  jointStateTopicChanged )
public:
  WaypointTool();

  ~WaypointTool() override;

  void activate() override;

  void deactivate() override;

  int processMouseEvent( rviz_common::ViewportMouseEvent &event ) override;

  int processKeyEvent( QKeyEvent *event, rviz_common::RenderPanel *panel ) override;

  QVariantList waypoints() const;

  Q_INVOKABLE void clearWaypoints();

  Q_INVOKABLE void removeWaypoint( int index );

  Q_INVOKABLE void addWaypoint( const QVector3D &position,
                                const QQuaternion &orientation = QQuaternion( 0, 0, 0, 0 ) );

  Q_INVOKABLE void addWaypoint( float x, float y, float z );

  Q_INVOKABLE void addWaypoint( float x, float y, float z, float qw, float qx, float qy, float qz );

  QString frame() const;

  QString robotDescriptionTopic() const;

  void setRobotDescriptionTopic( const QString &topic );

  QString jointStateTopic() const;

  void setJointStateTopic( const QString &topic );

signals:

  void waypointsChanged();

  void waypointRemoved( int index, QVariantMap waypoint );

  void waypointAdded( QVariantMap waypoint );

  void robotDescriptionTopicChanged( const QString &topic );

  void jointStateTopicChanged( const QString &topic );

private Q_SLOTS:
  void changedRobotDescriptionTopic();
  void changedJointStateTopic();
  void changedVisualizeRobot();
  void changedUseRobotCollision();
  void changedRobotAlpha();
  void changedRobotColor();

protected:
  void onInitialize() override;

  /// Shows the tool's control guide in the status bar.
  void updateStatus();

  WaypointPtr createWaypoint();
  bool initializeRobotModel();
  void resetRobotModel();

  void robotDescriptionCallback( const std_msgs::msg::String::ConstSharedPtr &msg );
  void jointStateCallback( const sensor_msgs::msg::JointState::ConstSharedPtr &msg );
  void updateJointStateSubscriber();

  std::unordered_map<std::string, Ogre::MeshPtr> mesh_resources_;
  WaypointPtr waypoint_preview_node_ = nullptr;
  std::vector<WaypointPtr> waypoint_nodes_;
  std::shared_ptr<rviz_rendering::ViewportProjectionFinder> projection_finder_;

  moveit::core::RobotModelConstPtr robot_model_;
  moveit::core::RobotStatePtr robot_state_;
  bool first_state_received_{ false };
  rclcpp::Subscription<std_msgs::msg::String>::SharedPtr robot_description_sub_;
  std::string robot_description_;
  std::unordered_map<std::string, std::string> robot_description_cache_;
  rclcpp::Subscription<sensor_msgs::msg::JointState>::SharedPtr joint_state_sub_;

  QVariantList waypoints_;
  // The waypoint that is currently placed. Nullptr if not currently in placing state.
  WaypointPtr active_waypoint_;
  rviz_common::properties::BoolProperty *raycast3d_property_ = nullptr;
  rviz_common::properties::BoolProperty *visualize_robot_property_ = nullptr;
  rviz_common::properties::Property *robot_property_tree_ = nullptr;
  rviz_common::properties::BoolProperty *use_robot_collision_property_ = nullptr;
  rviz_common::properties::FloatProperty *robot_alpha_property_ = nullptr;
  rviz_common::properties::ColorProperty *robot_color_property_ = nullptr;
  rviz_common::properties::RosTopicProperty *robot_description_topic_property_ = nullptr;
  rviz_common::properties::RosTopicProperty *joint_state_topic_property_ = nullptr;
};
} // namespace hector_user_interface

#endif // HECTOR_USER_INTERFACE_WAYPOINT_TOOL_H