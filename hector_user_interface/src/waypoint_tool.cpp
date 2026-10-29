//
// Created by Stefan Fabian on 23.03.21.
//

#include "hector_user_interface/waypoint_tool.h"
#include "logging.hpp"

#include <OgreEntity.h>
#include <OgreSubMesh.h>
#include <rviz_common/display_context.hpp>
#include <rviz_common/interaction/selection_manager.hpp>
#include <rviz_common/interaction/view_picker.hpp>
#include <rviz_common/properties/bool_property.hpp>
#include <rviz_common/properties/color_property.hpp>
#include <rviz_common/properties/float_property.hpp>
#include <rviz_common/properties/ros_topic_property.hpp>
#include <rviz_common/properties/string_property.hpp>
#include <rviz_common/viewport_mouse_event.hpp>
#include <rviz_default_plugins/robot/robot_link.hpp>
#include <rviz_rendering/geometry.hpp>
#include <rviz_rendering/mesh_loader.hpp>
#include <rviz_rendering/viewport_projection_finder.hpp>

#include <urdf/model.h>

#include <QVariant>
#include <QVector3D>

namespace hector_user_interface
{

WaypointTool::WaypointTool() : InteractionTool()
{
  projection_finder_ = std::make_shared<rviz_rendering::ViewportProjectionFinder>();
  shortcut_key_ = 'w';
  using namespace rviz_common::properties;
  raycast3d_property_ = new BoolProperty(
      "3D Raycast", true,
      "If true, will use scene manager to find intersection with compatible displayed entities. "
      "If false, will only check for intersection with ground plane.",
      this->getPropertyContainer() );
  visualize_robot_property_ = new BoolProperty(
      "Visualize Robot", false,
      "If true, will display the robot model when defining a waypoint with orientation."
      "If false, always shows the default flag as waypoint marker.",
      this->getPropertyContainer(), SLOT( changedVisualizeRobot() ), this );
  robot_description_topic_property_ = new RosTopicProperty(
      "Robot Description", "robot_description", "std_msgs/msg/String",
      "The ROS topic where the URDF for the robot is published", this->getPropertyContainer(),
      SLOT( changedRobotDescriptionTopic() ), this );
  joint_state_topic_property_ =
      new RosTopicProperty( "Joint State Topic", "joint_states", "sensor_msgs/msg/JointState",
                            "The topic on which the sensor_msgs::JointState messages are received",
                            this->getPropertyContainer(), SLOT( changedJointStateTopic() ), this );

  robot_property_tree_ = new Property( "Robot Model", QVariant(), "", this->getPropertyContainer() );
  use_robot_collision_property_ =
      new BoolProperty( "Use Collision Model", true,
                        "If true, uses the collision geometry to display the robot model"
                        "If false, uses the visual goemetry to display the robot model",
                        robot_property_tree_, SLOT( changedUseRobotCollision() ), this );
  robot_alpha_property_ =
      new FloatProperty( "Alpha", 0.8, "Changes the robot visualization transparency.",
                         robot_property_tree_, SLOT( changedRobotAlpha() ), this );
  robot_alpha_property_->setMin( 0.0 );
  robot_alpha_property_->setMax( 1.0 );
  robot_color_property_ =
      new ColorProperty( "Color", Qt::white, "Changes the robot visualization color.",
                         robot_property_tree_, SLOT( changedRobotColor() ), this );
}

WaypointTool::~WaypointTool() { blockSignals( true ); }

void WaypointTool::onInitialize()
{
  InteractionTool::onInitialize();
  robot_description_topic_property_->initialize( context_->getRosNodeAbstraction() );
  joint_state_topic_property_->initialize( context_->getRosNodeAbstraction() );
  Ogre::MeshPtr preview_mesh =
      rviz_rendering::loadMeshFromResource( Waypoint::WAYPOINT_PREVIEW_RESOURCE );
  if ( !preview_mesh ) {
    UI_LOG_ERROR( "Failed to load waypoint tool preview mesh." );
    return;
  }
  mesh_resources_.emplace( Waypoint::WAYPOINT_PREVIEW_RESOURCE, preview_mesh );
  Ogre::MeshPtr arrow_mesh =
      rviz_rendering::loadMeshFromResource( Waypoint::WAYPOINT_ARROW_RESOURCE );
  if ( !arrow_mesh ) {
    UI_LOG_ERROR( "Failed to load waypoint tool orientation preview mesh." );
    return;
  }
  mesh_resources_.emplace( Waypoint::WAYPOINT_ARROW_RESOURCE, arrow_mesh );
  waypoint_preview_node_ = createWaypoint();
  waypoint_preview_node_->setVisible( false );
  initializeRobotModel();
  // Subscribe with the initial property values; the changed-slots only fire on later edits
  changedRobotDescriptionTopic();
  updateJointStateSubscriber();
}

void WaypointTool::activate()
{
  updateJointStateSubscriber();
  if ( waypoint_preview_node_ ) {
    waypoint_preview_node_->setVisible( true );
  }
  updateStatus();
}

void WaypointTool::updateStatus()
{
  setStatus( "<b>Left-Click + Drag:</b> Place waypoint and set heading.  "
             "<b>Right-Click:</b> Remove last waypoint.  "
             "<b>Hold Ctrl:</b> Move camera." );
}

void WaypointTool::deactivate()
{
  joint_state_sub_.reset();
  if ( waypoint_preview_node_ ) {
    waypoint_preview_node_->setVisible( false );
  }
}

namespace
{

template<typename Scalar>
Scalar square( Scalar x )
{
  return x * x;
}

} // namespace

int WaypointTool::processMouseEvent( rviz_common::ViewportMouseEvent &event )
{
  if ( waypoint_preview_node_ == nullptr )
    return InteractionTool::processMouseEvent( event );

  // While holding Ctrl, defer to the interaction tool so the camera can be moved
  // (orbit/pan/zoom) without leaving the waypoint tool. Skip while a placement is in
  // progress so an ongoing left-drag is not interrupted.
  if ( event.control() && active_waypoint_ == nullptr ) {
    waypoint_preview_node_->setVisible( false );
    return InteractionTool::processMouseEvent( event );
  }

  // Perform raycast
  waypoint_preview_node_->setVisible( false ); // Disable for raycast
  if ( active_waypoint_ )
    active_waypoint_->setVisible( false );
  for ( const auto &waypoint : waypoint_nodes_ ) { waypoint->setVisible( false ); }
  Ogre::Vector3 intersection;
  if ( !raycast3d_property_->getBool() ||
       !context_->getViewPicker()->get3DPoint( event.panel, event.x, event.y, intersection ) ) {
    // Fall back to plane intersection
    Ogre::Plane ground_plane( Ogre::Vector3::UNIT_Z, 0.f );
    bool success = false;
    std::tie( success, intersection ) = projection_finder_->getViewportPointProjectionOnXYPlane(
        event.panel->getRenderWindow(), event.x, event.y );
    if ( !success ) {
      // Restore visibility disabled for the raycast
      if ( active_waypoint_ )
        active_waypoint_->setVisible( true );
      for ( const auto &waypoint : waypoint_nodes_ ) { waypoint->setVisible( true ); }
      return 0;
    }
  }
  // Restore visibility
  if ( active_waypoint_ )
    active_waypoint_->setVisible( true );
  for ( const auto &waypoint : waypoint_nodes_ ) { waypoint->setVisible( true ); }

  // Show preview node at current intersection unless we are in the process of placing a waypoint
  waypoint_preview_node_->setVisible( active_waypoint_ == nullptr );
  waypoint_preview_node_->setPosition( intersection );
  if ( event.leftDown() ) {
    active_waypoint_ = createWaypoint();
    active_waypoint_->setPosition( intersection );
    active_waypoint_->setOrientation( Ogre::Quaternion::ZERO );
    return Render;
  }
  if ( event.rightDown() ) {
    if ( active_waypoint_ ) {
      // Only cancel the placement in progress, don't also remove the last committed waypoint
      active_waypoint_ = nullptr;
      return Render;
    }
    // Right click removes last waypoint
    if ( waypoint_nodes_.empty() )
      return 0;
    removeWaypoint( static_cast<int>( waypoint_nodes_.size() - 1 ) );
    return Render;
  }
  if ( active_waypoint_ ) {
    const Ogre::Vector3 &waypoint_position = active_waypoint_->getPosition();
    Ogre::Real offset_x = intersection.x - waypoint_position.x;
    Ogre::Real offset_y = intersection.y - waypoint_position.y;
    Ogre::Real length = std::sqrt( square( offset_x ) + square( offset_y ) );
    if ( length > 1E-6 ) {
      offset_x /= 2 * length;
      offset_y /= 2 * length;
    }
    // Rotate the arrow so it points in the direction of the intersection
    Ogre::Real angle = std::atan2( offset_y, offset_x );
    Ogre::Quaternion orientation = Ogre::Quaternion::ZERO;
    if ( length >= 0.1 ) {
      orientation = Ogre::Quaternion( std::cos( angle / 2 ), 0, 0, std::sin( angle / 2 ) );
    }
    active_waypoint_->setOrientation( orientation );
    if ( event.leftUp() ) {
      waypoint_nodes_.push_back( active_waypoint_ );
      QVariantMap waypoint;
      waypoint.insert( "position",
                       QVector3D( waypoint_position.x, waypoint_position.y, waypoint_position.z ) );
      waypoint.insert( "orientation",
                       QQuaternion( orientation.w, orientation.x, orientation.y, orientation.z ) );
      waypoints_.push_back( waypoint );
      emit waypointAdded( waypoint );
      emit waypointsChanged();
      active_waypoint_ = nullptr;
    }
    return Render;
  }
  auto result = InteractionTool::processMouseEvent( event );
  updateStatus();
  return result;
}

int WaypointTool::processKeyEvent( QKeyEvent *event, rviz_common::RenderPanel *panel )
{
  return InteractionTool::processKeyEvent( event, panel );
}

QVariantList WaypointTool::waypoints() const { return waypoints_; }

void WaypointTool::clearWaypoints()
{
  waypoint_nodes_.clear();
  waypoints_.clear();
  emit waypointsChanged();
}

QString WaypointTool::frame() const { return context_->getFixedFrame(); }

QString WaypointTool::robotDescriptionTopic() const
{
  return robot_description_topic_property_->getString();
}

void WaypointTool::setRobotDescriptionTopic( const QString &topic )
{
  robot_description_topic_property_->setString( topic );
}

QString WaypointTool::jointStateTopic() const { return joint_state_topic_property_->getString(); }

void WaypointTool::setJointStateTopic( const QString &topic )
{
  joint_state_topic_property_->setString( topic );
}

Q_INVOKABLE void WaypointTool::removeWaypoint( int index )
{
  if ( index >= waypoints_.size() || index >= static_cast<int>( waypoint_nodes_.size() ) ||
       index < 0 ) {
    UI_LOG_ERROR_STREAM( "Index " << index << " out of bounds." );
    return;
  }
  waypoint_nodes_.erase( waypoint_nodes_.begin() + index );
  QVariantMap waypoint = waypoints_[index].toMap();
  waypoints_.removeAt( index );
  emit waypointRemoved( index, waypoint );
  emit waypointsChanged();
}

Q_INVOKABLE void WaypointTool::addWaypoint( const QVector3D &position, const QQuaternion &orientation )
{
  // Keep waypoint_nodes_ and waypoints_ in lockstep. removeWaypoint erases from both by index
  WaypointPtr node = createWaypoint();
  node->setPosition( Ogre::Vector3( position.x(), position.y(), position.z() ) );
  node->setOrientation(
      Ogre::Quaternion( orientation.scalar(), orientation.x(), orientation.y(), orientation.z() ) );
  waypoint_nodes_.push_back( node );
  QVariantMap waypoint;
  waypoint.insert( "position", position );
  waypoint.insert( "orientation", orientation );
  waypoints_.push_back( waypoint );
  emit waypointAdded( waypoint );
  emit waypointsChanged();
}

Q_INVOKABLE void WaypointTool::addWaypoint( float x, float y, float z )
{
  addWaypoint( x, y, z, 0, 0, 0, 0 );
}

Q_INVOKABLE void WaypointTool::addWaypoint( float x, float y, float z, float qw, float qx, float qy,
                                            float qz )
{
  addWaypoint( QVector3D( x, y, z ), QQuaternion( qw, qx, qy, qz ) );
}

bool WaypointTool::initializeRobotModel()
{
  if ( robot_description_.empty() )
    return false;
  auto urdf = std::make_shared<urdf::Model>();
  if ( !urdf->initString( robot_description_ ) ) {
    return false;
  }
  auto srdf = std::make_shared<srdf::Model>();

  try {
    robot_model_ = std::make_shared<moveit::core::RobotModel>( urdf, srdf );
    robot_state_ = std::make_shared<moveit::core::RobotState>( robot_model_ );
  } catch ( std::exception &e ) {
    UI_LOG_ERROR_STREAM( "Failed to initialize robot model in waypoint tool: " << e.what() );
    return false;
  }
  robot_state_->setToDefaultValues();
  first_state_received_ = false;

  if ( active_waypoint_ ) {
    active_waypoint_->setRobotModel( robot_state_ );
  }
  for ( const auto &waypoint : waypoint_nodes_ ) { waypoint->setRobotModel( robot_state_ ); }
  // Re-apply in case "Visualize Robot" was enabled before the model became available
  changedVisualizeRobot();
  return true;
}

void WaypointTool::changedRobotDescriptionTopic()
{
  auto node = context_->getRosNodeAbstraction().lock();
  emit robotDescriptionTopicChanged( robot_description_topic_property_->getString() );
  if ( !node ) {
    UI_LOG_ERROR( "No ROS node abstraction available for WaypointTool." );
    return;
  }
  robot_description_sub_ = node->get_raw_node()->create_subscription<std_msgs::msg::String>(
      robot_description_topic_property_->getStdString(), rclcpp::QoS( 1 ).transient_local(),
      [this]( const std_msgs::msg::String::ConstSharedPtr &msg ) {
        // The subscription is called from the ROS spin thread; marshal to the GUI thread since
        // the callback mutates the robot model and Ogre scene used by rendering and mouse events
        QMetaObject::invokeMethod(
            this, [this, msg]() { robotDescriptionCallback( msg ); }, Qt::QueuedConnection );
      } );
  auto cache_it = robot_description_cache_.find( robot_description_sub_->get_topic_name() );
  if ( cache_it == robot_description_cache_.end() )
    return;
  robot_description_ = cache_it->second;
  resetRobotModel();
  initializeRobotModel();
  updateJointStateSubscriber();
}

void WaypointTool::changedJointStateTopic()
{
  emit jointStateTopicChanged( joint_state_topic_property_->getString() );
  updateJointStateSubscriber();
}

void WaypointTool::changedVisualizeRobot()
{
  bool visualize_robot = visualize_robot_property_->getBool() && robot_state_;
  updateJointStateSubscriber();
  if ( active_waypoint_ ) {
    active_waypoint_->setVisualizeRobot( visualize_robot );
  }
  for ( const auto &waypoint : waypoint_nodes_ ) { waypoint->setVisualizeRobot( visualize_robot ); }
}

void WaypointTool::changedUseRobotCollision()
{
  if ( active_waypoint_ ) {
    active_waypoint_->setUseRobotCollision( use_robot_collision_property_->getBool() );
  }
  for ( const auto &waypoint : waypoint_nodes_ ) {
    waypoint->setUseRobotCollision( use_robot_collision_property_->getBool() );
  }
}

void WaypointTool::changedRobotAlpha()
{
  if ( active_waypoint_ ) {
    active_waypoint_->setRobotAlpha( robot_alpha_property_->getFloat() );
  }
  for ( const auto &waypoint : waypoint_nodes_ ) {
    waypoint->setRobotAlpha( robot_alpha_property_->getFloat() );
  }
}

void WaypointTool::changedRobotColor()
{
  if ( active_waypoint_ ) {
    active_waypoint_->setRobotColor( robot_color_property_->getColor() );
  }
  for ( const auto &waypoint : waypoint_nodes_ ) {
    waypoint->setRobotColor( robot_color_property_->getColor() );
  }
}

void WaypointTool::robotDescriptionCallback( const std_msgs::msg::String::ConstSharedPtr &msg )
{
  auto cache_it = robot_description_cache_.find( robot_description_sub_->get_topic_name() );
  if ( cache_it != robot_description_cache_.end() && cache_it->second == msg->data ) {
    // No change in robot description
    return;
  }
  robot_description_cache_[robot_description_sub_->get_topic_name()] = msg->data;
  robot_description_ = msg->data;
  resetRobotModel();
  initializeRobotModel();
  updateJointStateSubscriber();
}

void WaypointTool::jointStateCallback( const sensor_msgs::msg::JointState::ConstSharedPtr &joint_state_msg )
{
  if ( robot_state_ ) {
    robot_state_->setVariableValues( *joint_state_msg );
    if ( active_waypoint_ ) {
      active_waypoint_->updateRobotState( robot_state_ );
    }
    if ( !first_state_received_ ) {
      for ( const auto &waypoint : waypoint_nodes_ ) { waypoint->updateRobotState( robot_state_ ); }
      first_state_received_ = true;
    }
  }
}

void WaypointTool::resetRobotModel()
{
  robot_model_ = nullptr;
  robot_state_ = nullptr;
  if ( active_waypoint_ ) {
    active_waypoint_->setRobotModel( nullptr );
  }
  for ( const auto &waypoint : waypoint_nodes_ ) { waypoint->setRobotModel( nullptr ); }
}

WaypointPtr WaypointTool::createWaypoint()
{
  auto waypoint =
      std::make_shared<Waypoint>( scene_manager_->getRootSceneNode()->createChildSceneNode(),
                                  context_, this->getPropertyContainer(), mesh_resources_ );
  waypoint->setRobotModel( robot_state_ );
  waypoint->setRobotColor( robot_color_property_->getColor() );
  waypoint->setUseRobotCollision( use_robot_collision_property_->getBool() );
  waypoint->setRobotAlpha( robot_alpha_property_->getFloat() );
  waypoint->setVisualizeRobot( visualize_robot_property_->getBool() );
  return waypoint;
}

void WaypointTool::updateJointStateSubscriber()
{
  if ( visualize_robot_property_->getBool() && robot_state_ ) {
    if ( joint_state_sub_ &&
         joint_state_topic_property_->getStdString() == joint_state_sub_->get_topic_name() ) {
      // No change in joint state topic
      return;
    }
    joint_state_sub_.reset();
    auto node = context_->getRosNodeAbstraction().lock();
    if ( !node ) {
      UI_LOG_ERROR( "No ROS node abstraction available for WaypointTool." );
      return;
    }
    joint_state_sub_ = node->get_raw_node()->create_subscription<sensor_msgs::msg::JointState>(
        joint_state_topic_property_->getStdString(), 10,
        [this]( const sensor_msgs::msg::JointState::ConstSharedPtr &msg ) {
          // Marshal to the GUI thread — the callback updates the robot state visualization
          QMetaObject::invokeMethod(
              this, [this, msg]() { jointStateCallback( msg ); }, Qt::QueuedConnection );
        } );
  } else {
    joint_state_sub_.reset();
  }
}

} // namespace hector_user_interface

#include <pluginlib/class_list_macros.hpp>
PLUGINLIB_EXPORT_CLASS( hector_user_interface::WaypointTool, rviz_common::Tool )
