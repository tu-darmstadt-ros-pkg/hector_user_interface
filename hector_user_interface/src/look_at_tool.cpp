//
// Created by Jonas Suess on 19.04.2023
//

#include "hector_user_interface/look_at_tool.h"

#include "look_at_common.hpp"

#include <rviz_common/display_context.hpp>
#include <rviz_common/interaction/view_picker_iface.hpp>
#include <rviz_common/render_panel.hpp>
#include <rviz_common/tool_manager.hpp>
#include <rviz_common/view_manager.hpp>
#include <rviz_common/viewport_mouse_event.hpp>

#include <QKeyEvent>

using InteractionTool = rviz_default_plugins::tools::InteractionTool;

namespace hector_user_interface
{

LookAtTool::LookAtTool() { shortcut_key_ = 'l'; }

void LookAtTool::activate()
{
  context_->getViewManager()->getRenderPanel()->installEventFilter( this );
  updateStatus();
}

void LookAtTool::updateStatus()
{
  if ( mode_ == last_status_mode_ )
    return;
  last_status_mode_ = mode_;
  switch ( mode_ ) {
  case MODE_PREVIEW:
    setStatus( "<b>Left-Click:</b> Place look-at point and start aiming." );
    break;
  case MODE_ADAPT_DIRECTION:
    setStatus( "<b>Drag:</b> Aim direction.  <b>Wheel:</b> Move along view ray.  "
               "<b>Shift:</b> Move sideways.  <b>Release:</b> Set distance." );
    break;
  case MODE_ADAPT_POSITION:
    setStatus( "<b>Drag:</b> Move sideways.  <b>Wheel:</b> Move along view ray.  "
               "<b>Release Shift:</b> Back to aiming.  <b>Release:</b> Set distance." );
    break;
  case MODE_ADAPT_DISTANCE:
    setStatus( "<b>Wheel:</b> Adjust distance.  <b>Hold Ctrl:</b> Keep adjusting.  "
               "<b>Move/Click:</b> Finish." );
    break;
  }
}

void LookAtTool::deactivate()
{
  context_->getViewManager()->getRenderPanel()->removeEventFilter( this );
  if ( preview_arrow_ != nullptr )
    preview_arrow_->getSceneNode()->setVisible( false );
}

void LookAtTool::onInitialize()
{
  InteractionTool::onInitialize();
  preview_arrow_ =
      createArrow( scene_manager_, Ogre::Vector3::ZERO, Ogre::Vector3::UNIT_X, arrow_length_, 0.7 );
  arrow_ = createArrow( scene_manager_, Ogre::Vector3::ZERO, Ogre::Vector3::UNIT_X, arrow_length_ );
}

int LookAtTool::processMouseEvent( rviz_common::ViewportMouseEvent &event )
{
  updateStatus();
  if ( preview_arrow_ == nullptr )
    return InteractionTool::processMouseEvent( event );
  if ( arrow_ == nullptr )
    return InteractionTool::processMouseEvent( event );

  // Show preview arrow
  if ( mode_ == MODE_PREVIEW ) {
    // Compute raycast to get position of arrow
    preview_arrow_->getSceneNode()->setVisible( false );
    arrow_->getSceneNode()->setVisible( false );
    bool raycast_hit =
        context_->getViewPicker()->get3DPoint( event.panel, event.x, event.y, intersection_ );
    if ( raycast_hit ) {
      Ogre::Vector3 camera_offset = intersection_ - cameraPosition( event );
      raycast_hit = camera_offset.length() > 1E-6;
      if ( raycast_hit ) {
        camera_offset.normalise();
        // compute normal at preview arrow position -> this will be the initial direction
        if ( getNormalAtPoint( context_, event, normal_ ) ) {
          if ( normal_.dotProduct( camera_offset ) < 0 )
            normal_ *= -1;
        } else {
          normal_ = camera_offset;
        }
        preview_arrow_position_ = intersection_ - normal_ * arrow_length_;
        preview_arrow_->setPosition( preview_arrow_position_ );
        preview_arrow_->setDirection( normal_ );
        preview_arrow_->getSceneNode()->setVisible( true );
      }
    }

    // Place arrow only where the current raycast succeeded
    if ( raycast_hit && event.leftDown() ) {
      arrow_direction_ = normal_;
      arrow_position_ = preview_arrow_position_;
      arrow_->setPosition( arrow_position_ );
      arrow_->setDirection( arrow_direction_ );
      arrow_->getSceneNode()->setVisible( true );
      preview_arrow_->getSceneNode()->setVisible( false );

      mode_ = MODE_ADAPT_DIRECTION;
      mouse_position_ = { event.x, event.y };
      original_arrow_direction_ = arrow_direction_;
      emit lookAtChanged();
      return Render;
    }
  } else if ( mode_ == MODE_ADAPT_DIRECTION ) {
    // Releasing the left button freezes the current orientation and switches to distance adaption.
    if ( !event.left() ) {
      mode_ = MODE_ADAPT_DISTANCE;
      return Render;
    }
    if ( event.right() )
      return InteractionTool::processMouseEvent( event );
    // adapt intersection point along current arrow_direction
    Ogre::Real wheel_delta = event.wheel_delta * scroll_factor_;
    intersection_ += wheel_delta * arrow_direction_;
    // y-Difference -> turn direction around vector vec
    Ogre::Vector3 axis = computeTurnAxis( original_arrow_direction_, intersection_, event );
    Ogre::Vector3 vec = original_arrow_direction_.crossProduct( axis );
    Ogre::Quaternion rot = Ogre::Quaternion(
        Ogre::Degree( change_direction_factor_ * ( event.y - mouse_position_.second ) ), vec );
    arrow_direction_ = rot * original_arrow_direction_;
    // x-Difference
    vec = axis;
    rot = Ogre::Quaternion(
        Ogre::Degree( change_direction_factor_ * ( event.x - mouse_position_.first ) ), vec );
    arrow_direction_ = rot * arrow_direction_;
    // set new position (end of arrow not tip) and direction
    arrow_position_ = intersection_ - arrow_direction_ * arrow_length_;
    arrow_->setDirection( arrow_direction_ );
    arrow_->setPosition( arrow_position_ );
    mouse_position_translation_ = { event.x, event.y };
    emit lookAtChanged();
    return Render;
  } else if ( mode_ == MODE_ADAPT_POSITION ) {
    if ( !event.left() )
      mode_ = MODE_ADAPT_DISTANCE;
    if ( event.right() )
      return InteractionTool::processMouseEvent( event );
    // adapt intersection point along current arrow_direction
    Ogre::Real wheel_delta = event.wheel_delta * scroll_factor_;
    intersection_ += wheel_delta * arrow_direction_;
    // y-Difference -> move direction along vector vec
    Ogre::Vector3 axis = computeTurnAxis( original_arrow_direction_, intersection_, event );
    Ogre::Vector3 vec = original_arrow_direction_.crossProduct( axis );
    intersection_ += change_position_factor_ * ( event.x - mouse_position_translation_.first ) * vec;
    // x-Difference
    vec = axis;
    intersection_ -= change_position_factor_ * ( event.y - mouse_position_translation_.second ) * vec;
    // set new position (end of arrow not tip) and direction
    arrow_position_ = intersection_ - arrow_direction_ * arrow_length_;
    arrow_->setPosition( arrow_position_ );
    mouse_position_translation_ = { event.x, event.y };
    emit lookAtChanged();
    return Render;

  } else if ( mode_ == MODE_ADAPT_DISTANCE ) {
    if ( event.wheel_delta != 0 ) {
      Ogre::Vector3 scrollOffset = event.wheel_delta * scroll_factor_ * arrow_direction_;
      arrow_position_ += scrollOffset;
      intersection_ += scrollOffset;
      arrow_->setPosition( arrow_position_ );
      emit lookAtChanged();
      return Render;
    } else if ( !event.control() ) {
      exitLookAt();
    }
  }

  return InteractionTool::processMouseEvent( event );
}

bool LookAtTool::eventFilter( QObject *object, QEvent *event )
{
  // Mouse events and key presses are delivered through processMouseEvent() and processKeyEvent().
  // rviz has no tool callback for key releases though, so this filter observes the render panel's
  // events to catch the Control/Shift releases that change mode. The Shift press is handled here as
  // well to keep all key handling in one place.
  if ( event->type() == QEvent::KeyRelease ) {
    auto *keyEvent = dynamic_cast<QKeyEvent *>( event );
    if ( keyEvent->key() == Qt::Key_Control ) {
      if ( mode_ == MODE_ADAPT_DISTANCE ) {
        exitLookAt();
      }
    } else {
      if ( keyEvent->key() == Qt::Key_Shift ) {
        if ( mode_ == MODE_ADAPT_POSITION ) {
          mode_ = MODE_ADAPT_DIRECTION;
          mouse_position_ = mouse_position_translation_;
        }
      }
    }
  } else if ( event->type() == QEvent::KeyPress ) {
    auto *keyEvent = dynamic_cast<QKeyEvent *>( event );
    if ( keyEvent->key() == Qt::Key_Shift ) {
      if ( mode_ == MODE_ADAPT_DIRECTION ) {
        mode_ = MODE_ADAPT_POSITION;
        mouse_position_translation_ = mouse_position_;
      }
    }
  }
  updateStatus();
  return false;
}

void LookAtTool::exitLookAt()
{
  mode_ = MODE_PREVIEW;
  context_->getToolManager()->setCurrentTool( context_->getToolManager()->getDefaultTool() );
}

QVector3D LookAtTool::lookAtPosition() const
{
  return { intersection_.x, intersection_.y, intersection_.z };
}

QVector3D LookAtTool::lookAtDirection() const
{
  return { arrow_direction_.x, arrow_direction_.y, arrow_direction_.z };
}

QQuaternion LookAtTool::lookAtOrientation() const
{
  return directionToQuaternion( arrow_direction_ );
}

} // namespace hector_user_interface

#include <pluginlib/class_list_macros.hpp>

PLUGINLIB_EXPORT_CLASS( hector_user_interface::LookAtTool, rviz_common::Tool )
