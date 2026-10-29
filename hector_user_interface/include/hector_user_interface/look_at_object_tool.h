//
// Created by Aljoscha Schmidt on 01.05.2023
//

#ifndef HECTOR_USER_INTERFACE_LOOK_AT_OBJECT_TOOL_H
#define HECTOR_USER_INTERFACE_LOOK_AT_OBJECT_TOOL_H

#include <rviz_common/properties/string_property.hpp>
#include <rviz_default_plugins/tools/interaction/interaction_tool.hpp>
#include <rviz_rendering/objects/arrow.hpp>

#include <OgreMatrix3.h>
#include <OgreVector.h>
#include <QQuaternion>
#include <QVariantList>
#include <QVector3D>

#include <memory>
#include <utility>
#include <vector>

namespace hector_user_interface
{

class LookAtObjectTool : public rviz_default_plugins::tools::InteractionTool
{
  Q_OBJECT
  Q_PROPERTY( QVector3D lookAtPosition READ lookAtPosition NOTIFY lookAtChanged )
  Q_PROPERTY( QVector3D lookAtDirection READ lookAtDirection NOTIFY lookAtChanged )
  Q_PROPERTY( QQuaternion lookAtOrientation READ lookAtOrientation NOTIFY lookAtChanged )
  Q_PROPERTY( QVariantList lookAtMultiple READ lookAtMultiple NOTIFY lookAtChanged )

  enum SelectionMode {
    MODE_TEACH_PREVIEW,                     // -> with raycast get 3d position -> click set position
    MODE_TEACH_ADAPT_CURRENT_X_Y_DIRECTION, // -> with mouse clicked change direction, mousewheel position along ray

    MODE_USE_PREVIEW,
    MODE_USE_ADAPT_DIRECTION,
    MODE_USE_ADAPT_POSITION,
    MODE_LOOK_AT,
  };

public:
  LookAtObjectTool();

  void activate() override;

  void deactivate() override;

  int processMouseEvent( rviz_common::ViewportMouseEvent &event ) override;

  QVector3D lookAtPosition() const;

  QVector3D lookAtDirection() const;

  QQuaternion lookAtOrientation() const;

  QVariantList lookAtMultiple() const;

signals:

  void lookAtChanged();

protected:
  /// One arrow of the look-at configuration together with the poses it is derived from.
  /// Keeping these together guarantees they stay consistent when arrows are added or removed.
  struct LookAtArrow {
    std::unique_ptr<rviz_rendering::Arrow> arrow;
    /// Pose of the arrow in the fixed frame.
    Ogre::Vector3 position = Ogre::Vector3::ZERO;
    Ogre::Vector3 direction = Ogre::Vector3::UNIT_X;
    /// Pose relative to the configuration's first arrow. This is the representation that is saved
    /// to and loaded from the config file, and that the fixed frame pose is re-derived from when
    /// the configuration is placed on an object.
    Ogre::Vector3 original_position = Ogre::Vector3::ZERO;
    Ogre::Vector3 original_direction = Ogre::Vector3::UNIT_X;
    /// Point on the surface the arrow points at.
    Ogre::Vector3 intersection = Ogre::Vector3::ZERO;
  };

  void onInitialize() override;

  bool eventFilter( QObject *object, QEvent *event ) override;

  int handleMouseEvent( rviz_common::ViewportMouseEvent &event );

  /// Shows a control guide for the current mode in the status bar.
  void updateStatus();

  /// Saves the current arrows to ~/.ros/look_at_object_configs/<Config Name>, where <Config Name>
  /// is name_property_. Saving under distinct names creates separate configs that can be cycled
  /// through with Up/Down while placing (see updateFileName); reusing a name overwrites it.
  void saveArrowConfigToFile();
  bool readVectorsFromFile();
  bool getCurrentPositionAndNormal( rviz_common::ViewportMouseEvent &event,
                                    Ogre::Vector3 &intersection, Ogre::Vector3 &position,
                                    Ogre::Vector3 &normal, bool compute_normal = true );

  /// Derives the fixed frame pose of every arrow from its pose relative to the configuration's
  /// reference pose, placing the configuration at the given goal pose.
  void moveArrowPositionsAndOrientations( const Ogre::Vector3 &goal_position,
                                          const Ogre::Vector3 &goal_direction );
  /// Captures the current fixed frame poses as the configuration's reference representation.
  void moveArrowPositionsAndOrientations();
  void directionToRotationMatrix( Ogre::Matrix3 &matrix, const Ogre::Vector3 &direction );
  void updateColors();
  /// Applies the pose of every arrow to its scene node and makes it visible.
  void updateArrowSceneNodes();

  void updateFileName( bool advance = true );

  /// Currently selected arrow, or nullptr when there are no arrows.
  const LookAtArrow *selectedArrow() const;
  /// Keeps selected_arrow_index_ a valid index into arrows_ (or 0 when empty).
  void clampSelectedArrowIndex();

  std::vector<LookAtArrow> arrows_;
  std::unique_ptr<rviz_rendering::Arrow> preview_arrow_;
  Ogre::Vector3 preview_arrow_direction_ = Ogre::Vector3::UNIT_X;
  Ogre::Vector3 preview_arrow_position_ = Ogre::Vector3::ZERO;
  Ogre::Vector3 normal_ = Ogre::Vector3::UNIT_X;
  Ogre::Vector3 intersection_ = Ogre::Vector3::ZERO;
  std::pair<int, int> mouse_position_ = { 0, 0 }, mouse_position_translation_ = { 0, 0 };
  /// Pixel position of the last right-button press, used to tell a right click (remove last arrow)
  /// apart from a right drag (rotate camera).
  std::pair<int, int> right_press_position_ = { 0, 0 };
  Ogre::Real turn_angle_ = 0;
  Ogre::Real arrow_length_ = 0.3;
  Ogre::Real scroll_factor_ = 0.0005, scroll_factor_turn_ = 0.05;
  Ogre::Real change_direction_factor_ = 0.5, change_position_factor_ = 0.005;
  SelectionMode mode_ = MODE_TEACH_PREVIEW;
  /// Always a valid index into arrows_ unless arrows_ is empty.
  size_t selected_arrow_index_ = 0;
  /// Owned by the property container of this tool.
  rviz_common::properties::StringProperty *name_property_ = nullptr;
};
} // namespace hector_user_interface

#endif // HECTOR_USER_INTERFACE_LOOK_AT_OBJECT_TOOL_H
