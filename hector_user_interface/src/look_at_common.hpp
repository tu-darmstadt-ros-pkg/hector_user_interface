#ifndef HECTOR_USER_INTERFACE_LOOK_AT_COMMON_HPP
#define HECTOR_USER_INTERFACE_LOOK_AT_COMMON_HPP

#include <rviz_common/display_context.hpp>
#include <rviz_common/interaction/view_picker_iface.hpp>
#include <rviz_common/render_panel.hpp>
#include <rviz_common/view_controller.hpp>
#include <rviz_common/viewport_mouse_event.hpp>
#include <rviz_rendering/objects/arrow.hpp>

#include <OgreCamera.h>
#include <OgreSceneManager.h>
#include <OgreSceneNode.h>

#include <QQuaternion>

#include <cmath>
#include <memory>
#include <utility>
#include <vector>

namespace hector_user_interface
{

/// World position of the camera the given event was generated in. The camera is attached to a scene
/// node, so its world position is the derived one.
inline Ogre::Vector3 cameraPosition( const rviz_common::ViewportMouseEvent &event )
{
  return event.panel->getViewController()->getCamera()->getDerivedPosition();
}

/// Estimates the surface normal at the cursor by fitting a plane through three nearby raycast hits.
inline bool getNormalAtPoint( rviz_common::DisplayContext *context,
                              rviz_common::ViewportMouseEvent &event, Ogre::Vector3 &normal )
{
  // first implementation using just three points
  int offset_pixel = 3;
  std::vector<std::pair<int, int>> offsets = { { 1, 1 }, { -1, 1 }, { -1, -1 }, { 1, -1 }, { 1, 0 } };
  std::vector<Ogre::Vector3> intersections;
  for ( const auto &offset : offsets ) {
    Ogre::Vector3 intersection;
    if ( context->getViewPicker()->get3DPoint( event.panel, event.x + offset.first * offset_pixel,
                                               event.y + offset.second * offset_pixel,
                                               intersection ) ) {
      intersections.push_back( intersection );
    }
    if ( intersections.size() == 3 )
      break;
  }
  if ( intersections.size() < 3 )
    return false;
  normal =
      ( intersections[0] - intersections[1] ).crossProduct( ( intersections[0] - intersections[2] ) );
  normal.normalise();
  return true;
}

/// Creates an arrow attached to the scene manager's root node. The arrow starts out hidden.
inline std::unique_ptr<rviz_rendering::Arrow> createArrow( Ogre::SceneManager *scene_manager,
                                                           const Ogre::Vector3 &base,
                                                           const Ogre::Vector3 &direction,
                                                           double length, double alpha = 1.0 )
{
  auto arrow =
      std::make_unique<rviz_rendering::Arrow>( scene_manager, scene_manager->getRootSceneNode() );
  arrow->set( 0.75f * length, 0.025, 0.25f * length, 0.075 );
  arrow->setColor( 255.0 / 255.0, 210.0 / 255.0, 0, alpha );
  arrow->setPosition( base );
  arrow->setDirection( direction );
  arrow->getSceneNode()->setVisible( false );
  return arrow;
}

/// Rotation axis used when turning an arrow with the mouse. Defaults to the z-axis; if the reference
/// direction is close to vertical, the axis is turned toward the camera in the ground plane instead.
inline Ogre::Vector3 computeTurnAxis( const Ogre::Vector3 &reference_direction,
                                      const Ogre::Vector3 &intersection,
                                      const rviz_common::ViewportMouseEvent &event )
{
  Ogre::Vector3 axis = Ogre::Vector3::UNIT_Z;
  if ( std::abs( reference_direction.dotProduct( Ogre::Vector3::UNIT_Z ) ) > 0.5 ) {
    axis = intersection - cameraPosition( event );
    axis.z = 0;
    axis.normalise();
  }
  return axis;
}

inline QQuaternion directionToQuaternion( const Ogre::Vector3 &direction )
{
  Ogre::Quaternion orientation;

  Ogre::Vector3 xAxis = -direction;
  xAxis.normalise();
  Ogre::Vector3 zAxis = xAxis.crossProduct( Ogre::Vector3::UNIT_Z );
  zAxis.normalise();
  Ogre::Vector3 yAxis = zAxis.crossProduct( xAxis );
  yAxis.normalise();
  orientation.FromAxes( xAxis, yAxis, zAxis );

  return { orientation.w, orientation.x, orientation.y, orientation.z };
}

} // namespace hector_user_interface

#endif // HECTOR_USER_INTERFACE_LOOK_AT_COMMON_HPP
