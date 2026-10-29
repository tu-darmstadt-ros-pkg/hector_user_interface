#include <hector_user_interface/waypoint.h>

#include <OgreEntity.h>
#include <rviz_default_plugins/robot/robot_link.hpp>

namespace hector_user_interface
{

const float WAYPOINT_PREVIEW_SCALE = 0.1f;

const std::string Waypoint::WAYPOINT_PREVIEW_RESOURCE =
    "package://hector_user_interface/media/flag.dae";
const std::string Waypoint::WAYPOINT_ARROW_RESOURCE =
    "package://hector_user_interface/media/arrow.dae";

Waypoint::Waypoint( Ogre::SceneNode *parent_node, rviz_common::DisplayContext *context,
                    rviz_common::properties::Property *parent_property,
                    const std::unordered_map<std::string, Ogre::MeshPtr> &mesh_resources )
    : parent_node_( parent_node ), context_( context ), parent_property_( parent_property ),
      position_( Ogre::Vector3::ZERO ), orientation_( Ogre::Quaternion::ZERO ), visibility_( true ),
      flag_visibility_( true ), arrow_visibility_( false ), robot_visibility_( false ),
      visualize_robot_( false ), use_robot_collision_( false ), robot_color_( 0, 0, 0 ),
      robot_alpha_( 1.0f ), bounding_box_computed_( false ), robot_bb_offset_( 0.0f )
{
  // Load resources
  preview_mesh_ = mesh_resources.at( WAYPOINT_PREVIEW_RESOURCE );
  arrow_mesh_ = mesh_resources.at( WAYPOINT_ARROW_RESOURCE );

  waypoint_node_ = createWaypointNode( parent_node_ );
  arrow_node_ = createArrowNode( waypoint_node_ );
}

Waypoint::~Waypoint()
{
  destroyRobotVisualization();
  destroySceneNode( arrow_node_ );
  destroySceneNode( waypoint_node_ );
  destroySceneNode( parent_node_ );
}

void Waypoint::destroySceneNode( Ogre::SceneNode *node )
{
  if ( !node )
    return;
  Ogre::SceneManager *scene_manager = node->getCreator();
  while ( node->numAttachedObjects() > 0 ) {
    scene_manager->destroyMovableObject( node->getAttachedObject( 0 ) );
  }
  scene_manager->destroySceneNode( node );
}

void Waypoint::destroyRobotVisualization()
{
  robot_ = nullptr; // Destroy the visualization before the scene node it lives under
  if ( !robot_node_ )
    return;
  robot_node_->getCreator()->destroySceneNode( robot_node_ );
  robot_node_ = nullptr;
}

void Waypoint::setVisible( bool visible )
{
  visibility_ = visible;
  updateVisibility();
}

bool Waypoint::isVisible() const { return visibility_; }

void Waypoint::setPosition( const Ogre::Vector3 &position )
{
  position_ = position;
  waypoint_node_->setPosition( position );
  if ( robot_ ) {
    robot_->getRobot().setPosition( position + Ogre::Vector3( 0, 0, robot_bb_offset_ ) );
  }
}

const Ogre::Vector3 &Waypoint::getPosition() { return position_; }

void Waypoint::setOrientation( const Ogre::Quaternion &orientation )
{
  orientation_ = orientation;
  updateOrientationVisualization();
}

const Ogre::Quaternion &Waypoint::getOrientation() { return orientation_; }

void Waypoint::updateRobotState( const moveit::core::RobotStatePtr &state )
{
  robot_state_ = state;
  if ( robot_state_ && robot_ ) {
    robot_state_->update();
    bounding_box_computed_ = false;
    robot_->update( state );
  }
}

Ogre::SceneNode *Waypoint::createWaypointNode( Ogre::SceneNode *parent_node )
{
  Ogre::SceneNode *node = parent_node->createChildSceneNode();
  Ogre::Entity *entity = parent_node->getCreator()->createEntity( preview_mesh_ );
  node->attachObject( entity );
  node->setScale( WAYPOINT_PREVIEW_SCALE, WAYPOINT_PREVIEW_SCALE, WAYPOINT_PREVIEW_SCALE );
  return node;
}

Ogre::SceneNode *Waypoint::createArrowNode( Ogre::SceneNode *parent_node )
{
  Ogre::SceneNode *arrow_node = parent_node->createChildSceneNode();
  Ogre::Entity *entity = parent_node->getCreator()->createEntity( arrow_mesh_ );
  arrow_node->attachObject( entity );
  arrow_node->setVisible( false );
  arrow_node->setScale( 30 * WAYPOINT_PREVIEW_SCALE, 30 * WAYPOINT_PREVIEW_SCALE,
                        30 * WAYPOINT_PREVIEW_SCALE );
  return arrow_node;
}

moveit_rviz_plugin::RobotStateVisualizationPtr
Waypoint::createRobotVisualization( Ogre::SceneNode *parent_node )
{
  if ( !robot_state_ ) {
    return {};
  }
  robot_node_ = parent_node->createChildSceneNode();
  auto robot_vis = std::make_shared<moveit_rviz_plugin::RobotStateVisualization>(
      robot_node_, context_, "Robot State", parent_property_ );
  robot_vis->load( *robot_state_->getRobotModel()->getURDF() );
  robot_vis->getRobot().getLinkTreeProperty()->hide();
  robot_state_->update();
  robot_vis->update( robot_state_ );
  robot_vis->setAlpha( robot_alpha_ );
  setRobotCollision( robot_vis, use_robot_collision_ );
  setRobotColor( robot_vis, robot_color_ );
  robot_vis->setVisible( false );
  return robot_vis;
}

void Waypoint::setRobotColor( const QColor &color )
{
  robot_color_ = color;
  setRobotColor( robot_, robot_color_ );
}

bool Waypoint::isVisualizeRobot() const { return visualize_robot_; }

void Waypoint::setVisualizeRobot( bool visualize_robot )
{
  visualize_robot_ = visualize_robot;
  updateOrientationVisualization();
}

bool Waypoint::isUseRobotCollision() const { return use_robot_collision_; }

void Waypoint::setUseRobotCollision( bool use_robot_collision )
{
  use_robot_collision_ = use_robot_collision;
  setRobotCollision( robot_, use_robot_collision_ );
}

const QColor &Waypoint::getRobotColor() const { return robot_color_; }

float Waypoint::getRobotAlpha() const { return robot_alpha_; }

void Waypoint::setRobotAlpha( float robot_alpha )
{
  robot_alpha_ = robot_alpha;
  if ( robot_ ) {
    robot_->setAlpha( robot_alpha_ );
  }
}

void Waypoint::setRobotCollision( const moveit_rviz_plugin::RobotStateVisualizationPtr &robot,
                                  bool use_robot_collision )
{
  if ( !robot ) {
    return;
  }
  robot->setCollisionVisible( use_robot_collision );
  robot->setVisualVisible( !use_robot_collision );
}

void Waypoint::setRobotColor( const moveit_rviz_plugin::RobotStateVisualizationPtr &robot,
                              const QColor &color )
{
  if ( !robot ) {
    return;
  }
  for ( auto &entry : robot->getRobot().getLinks() ) {
    entry.second->setColor( color.redF(), color.greenF(), color.blueF() );
  }
}

void Waypoint::setRobotModel( const moveit::core::RobotStatePtr &robot_state )
{
  robot_state_ = robot_state;
  destroyRobotVisualization();
  bounding_box_computed_ = false;
  robot_bb_offset_ = 0.0f;
  updateOrientationVisualization();
}

void Waypoint::setNoOrientation()
{
  flag_visibility_ = true;
  arrow_visibility_ = false;
  robot_visibility_ = false;
  updateVisibility();
}

void Waypoint::setArrowOrientation( const Ogre::Quaternion &orientation )
{
  arrow_node_->setPosition( orientation * Ogre::Vector3{ 1, 0, 2 } );
  arrow_node_->setOrientation( orientation );
  flag_visibility_ = true;
  arrow_visibility_ = true;
  robot_visibility_ = false;
  updateVisibility();
}

void Waypoint::setRobotOrientation( const Ogre::Quaternion &orientation )
{
  flag_visibility_ = false;
  arrow_visibility_ = false;
  robot_visibility_ = true;

  // set offset position
  if ( !bounding_box_computed_ && robot_state_ ) {
    // Compute robot BB offset
    std::vector<double> aabb;
    robot_state_->computeAABB( aabb );
    if ( aabb.size() == 6 ) {
      bounding_box_computed_ = true;
      robot_bb_offset_ = static_cast<float>( -aabb[4] );
    }
  }
  Ogre::Vector3 robot_position = position_ + Ogre::Vector3( 0, 0, robot_bb_offset_ );
  robot_->getRobot().setPosition( robot_position );
  robot_->getRobot().setOrientation( orientation );
  updateVisibility();
}

void Waypoint::updateVisibility()
{
  waypoint_node_->setVisible( flag_visibility_ && visibility_, false );
  arrow_node_->setVisible( arrow_visibility_ && visibility_, false );
  if ( robot_ )
    robot_->setVisible( robot_visibility_ && visibility_ );
}

void Waypoint::updateOrientationVisualization()
{
  // No orientation
  if ( orientation_.Norm() <= 0 ) {
    setNoOrientation();
    return;
  }

  // Standard visualization
  if ( !visualize_robot_ ) {
    setArrowOrientation( orientation_ );
    return;
  }

  // Robot visualization
  if ( !robot_ ) {
    robot_ = createRobotVisualization( parent_node_ );
  }
  if ( !robot_ ) {
    // Fall back to arrow if initialization failed
    setArrowOrientation( orientation_ );
    return;
  }

  setRobotOrientation( orientation_ );
}

} // namespace hector_user_interface