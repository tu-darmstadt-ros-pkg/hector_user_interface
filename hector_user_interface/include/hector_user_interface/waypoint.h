#ifndef HECTOR_USER_INTERFACE_WAYPOINT_H
#define HECTOR_USER_INTERFACE_WAYPOINT_H

#include <OgreSceneNode.h>
#include <moveit_ros_visualization/moveit/rviz_plugin_render_tools/robot_state_visualization.hpp>
#include <unordered_map>

namespace hector_user_interface
{

class Waypoint
{
public:
  static const std::string WAYPOINT_PREVIEW_RESOURCE;
  static const std::string WAYPOINT_ARROW_RESOURCE;

public:
  //! Takes ownership of parent_node; it is destroyed together with the waypoint.
  Waypoint( Ogre::SceneNode *parent_node, rviz_common::DisplayContext *context,
            rviz_common::properties::Property *parent_property,
            const std::unordered_map<std::string, Ogre::MeshPtr> &mesh_resources );
  ~Waypoint();

  void setVisible( bool visible );
  bool isVisible() const;

  void setRobotModel( const moveit::core::RobotStatePtr &robot_state );

  void setPosition( const Ogre::Vector3 &position );
  const Ogre::Vector3 &getPosition();

  void setOrientation( const Ogre::Quaternion &orientation );
  const Ogre::Quaternion &getOrientation();

  void updateRobotState( const moveit::core::RobotStatePtr &state );

  bool isVisualizeRobot() const;
  void setVisualizeRobot( bool visualize_robot );

  bool isUseRobotCollision() const;
  void setUseRobotCollision( bool use_robot_collision );

  const QColor &getRobotColor() const;
  void setRobotColor( const QColor &color );

  float getRobotAlpha() const;
  void setRobotAlpha( float robot_alpha );

private:
  void updateVisibility();
  void updateOrientationVisualization();
  void setNoOrientation();
  void setArrowOrientation( const Ogre::Quaternion &orientation );
  void setRobotOrientation( const Ogre::Quaternion &orientation );
  void setRobotCollision( const moveit_rviz_plugin::RobotStateVisualizationPtr &robot,
                          bool use_robot_collision );
  void setRobotColor( const moveit_rviz_plugin::RobotStateVisualizationPtr &robot,
                      const QColor &color );

  Ogre::SceneNode *createWaypointNode( Ogre::SceneNode *parent_node );
  Ogre::SceneNode *createArrowNode( Ogre::SceneNode *parent_node );
  moveit_rviz_plugin::RobotStateVisualizationPtr
  createRobotVisualization( Ogre::SceneNode *parent_node );
  //! Destroys the node's attached movable objects and the node itself via its SceneManager.
  static void destroySceneNode( Ogre::SceneNode *node );
  void destroyRobotVisualization();

  Ogre::SceneNode *parent_node_;
  rviz_common::DisplayContext *context_;
  rviz_common::properties::Property *parent_property_;
  moveit::core::RobotStatePtr robot_state_;

  Ogre::SceneNode *waypoint_node_;
  Ogre::SceneNode *arrow_node_;
  Ogre::SceneNode *robot_node_ = nullptr;
  moveit_rviz_plugin::RobotStateVisualizationPtr robot_;

  Ogre::Vector3 position_;
  Ogre::Quaternion orientation_;

  bool visibility_;
  bool flag_visibility_;
  bool arrow_visibility_;
  bool robot_visibility_;

  bool visualize_robot_;

  bool use_robot_collision_;
  QColor robot_color_;
  float robot_alpha_;

  bool bounding_box_computed_;
  float robot_bb_offset_;

  Ogre::MeshPtr preview_mesh_;
  Ogre::MeshPtr arrow_mesh_;
};

typedef std::shared_ptr<Waypoint> WaypointPtr;

} // namespace hector_user_interface

#endif // HECTOR_USER_INTERFACE_WAYPOINT_H
