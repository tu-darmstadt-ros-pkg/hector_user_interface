//
// Created by Jonas Suess on 19.04.2023
//

#ifndef HECTOR_USER_INTERFACE_LOOK_AT_TOOL_H
#define HECTOR_USER_INTERFACE_LOOK_AT_TOOL_H

#include <rviz_default_plugins/tools/interaction/interaction_tool.hpp>
#include <rviz_rendering/objects/arrow.hpp>

#include <OgreVector.h>
#include <QQuaternion>
#include <QVector3D>

#include <memory>
#include <utility>

namespace hector_user_interface
{

class LookAtTool : public rviz_default_plugins::tools::InteractionTool
{
  Q_OBJECT
  Q_PROPERTY( QVector3D lookAtPosition READ lookAtPosition NOTIFY lookAtChanged )
  Q_PROPERTY( QVector3D lookAtDirection READ lookAtDirection NOTIFY lookAtChanged )
  Q_PROPERTY( QQuaternion lookAtOrientation READ lookAtOrientation NOTIFY lookAtChanged )

  enum SelectionMode {
    MODE_PREVIEW,
    MODE_ADAPT_DIRECTION,
    MODE_ADAPT_DISTANCE,
    MODE_ADAPT_POSITION
  };

public:
  LookAtTool();

  void activate() override;

  void deactivate() override;

  int processMouseEvent( rviz_common::ViewportMouseEvent &event ) override;

  QVector3D lookAtPosition() const;

  QVector3D lookAtDirection() const;

  QQuaternion lookAtOrientation() const;

signals:

  void lookAtChanged();

protected:
  void exitLookAt();

  /// Shows a control guide for the current mode in the status bar.
  void updateStatus();

  void onInitialize() override;

  bool eventFilter( QObject *object, QEvent *event ) override;

  std::unique_ptr<rviz_rendering::Arrow> arrow_;
  std::unique_ptr<rviz_rendering::Arrow> preview_arrow_;
  Ogre::Vector3 preview_arrow_position_ = Ogre::Vector3::ZERO;
  Ogre::Vector3 normal_ = Ogre::Vector3::UNIT_X;
  Ogre::Vector3 arrow_position_ = Ogre::Vector3::ZERO;
  Ogre::Vector3 arrow_direction_ = Ogre::Vector3::UNIT_X;
  Ogre::Vector3 original_arrow_direction_ = Ogre::Vector3::UNIT_X;
  /// Point on the surface the arrow points at, i.e. the arrow's tip.
  Ogre::Vector3 intersection_ = Ogre::Vector3::ZERO;
  std::pair<int, int> mouse_position_ = { 0, 0 }, mouse_position_translation_ = { 0, 0 };
  Ogre::Real arrow_length_ = 0.3;
  Ogre::Real scroll_factor_ = 0.0005;
  Ogre::Real change_direction_factor_ = 0.5;
  Ogre::Real change_position_factor_ = 0.005;
  SelectionMode mode_ = MODE_PREVIEW;
  // The mode for which the status is currently displayed. Used to avoid unnecessary updates.
  SelectionMode last_status_mode_ = MODE_PREVIEW;
};
} // namespace hector_user_interface

#endif // HECTOR_USER_INTERFACE_LOOK_AT_TOOL_H
