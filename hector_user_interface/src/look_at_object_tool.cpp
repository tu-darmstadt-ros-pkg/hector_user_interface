//
// Created by Aljoscha Schmidt on 01.05.2023
//

#include "hector_user_interface/look_at_object_tool.h"
#include "logging.hpp"
#include "look_at_common.hpp"

#include <rviz_common/display_context.hpp>
#include <rviz_common/interaction/view_picker_iface.hpp>
#include <rviz_common/render_panel.hpp>
#include <rviz_common/view_manager.hpp>
#include <rviz_common/viewport_mouse_event.hpp>

#include <QKeyEvent>

#include <algorithm>
#include <filesystem>
#include <fstream>
#include <sstream>

using InteractionTool = rviz_default_plugins::tools::InteractionTool;

namespace hector_user_interface
{
namespace fs = std::filesystem;

namespace
{
/// Maximum pixel travel between a right-button press and release for the gesture to still count as
/// a click (which removes the last arrow) rather than a drag (which rotates the camera).
constexpr int kRightClickMaxTravelPixels = 3;

fs::path configDirectory()
{
  const char *home = getenv( "HOME" );
  if ( home == nullptr ) {
    UI_LOG_ERROR_STREAM(
        "HOME environment variable is not set, cannot locate look at object configs." );
    return {};
  }
  return fs::path( home ) / ".ros" / "look_at_object_configs";
}
} // namespace

// Called when the UI is built (usually only once per Call of "hector sim")
LookAtObjectTool::LookAtObjectTool()
{
  shortcut_key_ = 'k'; // Used by the Rvis-Parent Class to define a hotkey that opens/closes the tool
  name_property_ = new rviz_common::properties::StringProperty(
      "Config Name", "LinearRail", "name of the config", this->getPropertyContainer() );
}

// Called when the Tool is opened from the UI
void LookAtObjectTool::activate()
{
  context_->getViewManager()->getRenderPanel()->installEventFilter( this );
  updateStatus();
}

void LookAtObjectTool::updateStatus()
{
  switch ( mode_ ) {
  case MODE_TEACH_PREVIEW:
    setStatus( "Teach: <b>Left-Click:</b> Add arrow.  <b>Right-Click:</b> Remove last.  "
               "<b>&larr;/&rarr;:</b> Select arrow.  <b>S:</b> Save.  "
               "<b>R:</b> Load.  <b>Q:</b> Clear." );
    break;
  case MODE_TEACH_ADAPT_CURRENT_X_Y_DIRECTION:
    setStatus( "<b>Drag:</b> Aim arrow.  <b>Wheel:</b> Move along ray.  <b>Release:</b> Done." );
    break;
  case MODE_USE_PREVIEW:
    setStatus( "Place: <b>Move:</b> Position config on surface.  <b>Left-Click:</b> Place.  "
               "<b>&uarr;/&darr;:</b> Switch config.  <b>Q:</b> Back to teaching." );
    break;
  case MODE_USE_ADAPT_DIRECTION:
    setStatus( "<b>Drag:</b> Aim.  <b>Wheel:</b> Turn.  <b>Shift:</b> Move position.  "
               "<b>Release:</b> Apply." );
    break;
  case MODE_USE_ADAPT_POSITION:
    setStatus( "<b>Drag:</b> Move position.  <b>Wheel:</b> Move along ray.  "
               "<b>Release Shift:</b> Back to aiming.  <b>Release:</b> Apply." );
    break;
  case MODE_LOOK_AT:
    setStatus( "<b>R:</b> Load config.  <b>&larr;/&rarr;:</b> Select arrow.  "
               "<b>Q:</b> New teaching." );
    break;
  }
}

// Called when the Tool is closed from the UI
void LookAtObjectTool::deactivate()
{
  context_->getViewManager()->getRenderPanel()->removeEventFilter( this );
  if ( preview_arrow_ != nullptr )
    preview_arrow_->getSceneNode()->setVisible( false );
  arrows_.clear();
  mode_ = MODE_TEACH_PREVIEW;
  selected_arrow_index_ = 0;
  emit lookAtChanged();
}

void LookAtObjectTool::onInitialize()
{
  InteractionTool::onInitialize();
  preview_arrow_ =
      createArrow( scene_manager_, Ogre::Vector3::ZERO, Ogre::Vector3::UNIT_X, arrow_length_, 0.7 );
}

bool LookAtObjectTool::getCurrentPositionAndNormal( rviz_common::ViewportMouseEvent &event,
                                                    Ogre::Vector3 &intersection,
                                                    Ogre::Vector3 &position, Ogre::Vector3 &normal,
                                                    bool compute_normal )
{
  if ( !context_->getViewPicker()->get3DPoint( event.panel, event.x, event.y, intersection ) )
    return false;
  Ogre::Vector3 camera_offset = intersection - cameraPosition( event );
  if ( camera_offset.length() <= 1E-6 )
    return false;
  camera_offset.normalise();
  // compute normal at preview arrow position -> this will be the initial direction
  if ( compute_normal && getNormalAtPoint( context_, event, normal ) ) {
    if ( normal.dotProduct( camera_offset ) < 0 )
      normal *= -1;
  } else {
    normal = camera_offset;
  }
  position = intersection - normal * arrow_length_;
  return true;
}

int LookAtObjectTool::processMouseEvent( rviz_common::ViewportMouseEvent &event )
{
  const int result = handleMouseEvent( event );
  // The base InteractionTool delegates camera movement to the active view controller, which
  // overwrites the status bar with its own hint on every event. Re-apply the tool's status so the
  // mode-specific help stays visible while the tool is active.
  updateStatus();
  return result;
}

int LookAtObjectTool::handleMouseEvent( rviz_common::ViewportMouseEvent &event )
{
  if ( event.control() ) // ignore everything if control is pressed
    return InteractionTool::processMouseEvent( event );
  if ( preview_arrow_ == nullptr )
    return InteractionTool::processMouseEvent( event );
  preview_arrow_->getSceneNode()->setVisible( false );
  // Show preview arrow
  if ( mode_ == MODE_TEACH_PREVIEW ) {
    if ( event.rightDown() )
      right_press_position_ = { event.x, event.y };
    // A right click removes the most recently placed arrow. A right drag rotates the camera (handled
    // by the interaction tool below), so it must not remove anything; the press-to-release travel
    // distinguishes the two. The left button being held means the user is placing, not removing.
    if ( event.rightUp() && !event.left() && !arrows_.empty() ) {
      const int dx = event.x - right_press_position_.first;
      const int dy = event.y - right_press_position_.second;
      if ( dx * dx + dy * dy <= kRightClickMaxTravelPixels * kRightClickMaxTravelPixels ) {
        arrows_.pop_back();
        clampSelectedArrowIndex();
        updateColors();
        emit lookAtChanged();
        return Render;
      }
    }
    if ( event.right() )
      return InteractionTool::processMouseEvent( event );
    // raycast to get position of arrow
    Ogre::Vector3 intersection;
    if ( getCurrentPositionAndNormal( event, intersection, preview_arrow_position_, normal_ ) ) {
      preview_arrow_->setPosition( preview_arrow_position_ );
      preview_arrow_->setDirection( normal_ );
      preview_arrow_->getSceneNode()->setVisible( true );
      // Place arrow only where the current raycast succeeded
      if ( event.leftDown() ) {
        preview_arrow_->getSceneNode()->setVisible( false );
        LookAtArrow &state = arrows_.emplace_back();
        state.intersection = intersection;
        state.direction = normal_;
        state.position = preview_arrow_position_;
        state.original_direction = state.direction;
        state.arrow =
            createArrow( scene_manager_, state.position, state.direction, arrow_length_, 0.7 );
        state.arrow->getSceneNode()->setVisible( true );
        updateColors();

        mode_ = MODE_TEACH_ADAPT_CURRENT_X_Y_DIRECTION;
        mouse_position_ = { event.x, event.y };
        emit lookAtChanged();
        return Render;
      }
    }
  } else if ( mode_ == MODE_TEACH_ADAPT_CURRENT_X_Y_DIRECTION ) {
    // Releasing the left button finishes adapting this arrow and returns to placing new ones.
    if ( !event.left() ) {
      mode_ = MODE_TEACH_PREVIEW;
      return Render;
    }
    if ( event.right() )
      return InteractionTool::processMouseEvent( event );
    if ( arrows_.empty() ) {
      mode_ = MODE_TEACH_PREVIEW;
      return InteractionTool::processMouseEvent( event );
    }
    LookAtArrow &state = arrows_.back();
    // adapt intersection point along current arrow_direction
    Ogre::Real wheel_delta = event.wheel_delta * scroll_factor_;
    state.intersection += wheel_delta * state.direction;
    // y-Difference -> turn direction around vector vec
    Ogre::Vector3 axis = computeTurnAxis( state.original_direction, state.intersection, event );
    Ogre::Vector3 vec = state.original_direction.crossProduct( axis );
    Ogre::Quaternion rot = Ogre::Quaternion(
        Ogre::Degree( change_direction_factor_ * ( event.y - mouse_position_.second ) ), vec );
    state.direction = rot * state.original_direction;
    // x-Difference
    vec = axis;
    rot = Ogre::Quaternion(
        Ogre::Degree( change_direction_factor_ * ( event.x - mouse_position_.first ) ), vec );
    state.direction = rot * state.direction;
    // set new position (end of arrow not tip) and direction
    state.position = state.intersection - state.direction * arrow_length_;
    state.arrow->setDirection( state.direction );
    state.arrow->setPosition( state.position );
    emit lookAtChanged();
    return Render;
  } else if ( mode_ == MODE_USE_PREVIEW ) {
    // Hide the config arrows so the picker samples the surface under the cursor, not the arrows
    // that follow it (which would otherwise make the config creep toward the camera each move).
    for ( LookAtArrow &state : arrows_ ) state.arrow->getSceneNode()->setVisible( false );
    // raycast to get position of arrow
    if ( getCurrentPositionAndNormal( event, intersection_, preview_arrow_position_, normal_,
                                      false ) ) {
      moveArrowPositionsAndOrientations( preview_arrow_position_, normal_ );
      updateArrowSceneNodes();
      emit lookAtChanged();
      // Place the configuration only where the current raycast succeeded
      if ( event.leftDown() ) {
        turn_angle_ = 0;
        mouse_position_ = { event.x, event.y };
        mode_ = MODE_USE_ADAPT_DIRECTION;
        return Render;
      }
    }
  } else if ( mode_ == MODE_USE_ADAPT_DIRECTION ) {
    // Releasing the left button finishes placing the configuration.
    if ( !event.left() ) {
      mode_ = MODE_LOOK_AT;
      return Render;
    }
    if ( event.right() )
      return InteractionTool::processMouseEvent( event );
    // adapt intersection point along current arrow_direction
    Ogre::Real wheel_delta = event.wheel_delta * scroll_factor_turn_;
    turn_angle_ += wheel_delta;
    // y-Difference -> turn direction around vector vec
    Ogre::Vector3 axis = computeTurnAxis( normal_, intersection_, event );
    Ogre::Vector3 vec = normal_.crossProduct( axis );
    Ogre::Quaternion rot = Ogre::Quaternion(
        Ogre::Degree( change_direction_factor_ * ( event.y - mouse_position_.second ) ), vec );
    preview_arrow_direction_ = rot * normal_;
    // x-Difference
    vec = axis;
    rot = Ogre::Quaternion(
        Ogre::Degree( change_direction_factor_ * ( event.x - mouse_position_.first ) ), vec );
    preview_arrow_direction_ = rot * preview_arrow_direction_;

    // set new position (end of arrow not tip) and direction
    preview_arrow_position_ = intersection_ - preview_arrow_direction_ * arrow_length_;
    moveArrowPositionsAndOrientations( preview_arrow_position_, preview_arrow_direction_ );
    updateArrowSceneNodes();
    mouse_position_translation_ = { event.x, event.y };
    emit lookAtChanged();
    return Render;
  } else if ( mode_ == MODE_USE_ADAPT_POSITION ) {
    // Releasing the left button finishes placing the configuration. Releasing Shift (handled in
    // eventFilter) returns to direction adaption instead.
    if ( !event.left() ) {
      mode_ = MODE_LOOK_AT;
      return Render;
    }
    if ( event.right() )
      return InteractionTool::processMouseEvent( event );
    // adapt intersection point along current arrow_direction
    Ogre::Real wheel_delta = event.wheel_delta * scroll_factor_;
    intersection_ += wheel_delta * preview_arrow_direction_;
    // y-Difference -> move direction along vector vec
    Ogre::Vector3 axis = computeTurnAxis( normal_, intersection_, event );
    Ogre::Vector3 vec = normal_.crossProduct( axis );
    intersection_ += change_position_factor_ * ( event.x - mouse_position_translation_.first ) * vec;
    // x-Difference
    vec = axis;
    intersection_ -= change_position_factor_ * ( event.y - mouse_position_translation_.second ) * vec;
    // set new position (end of arrow not tip) and direction
    preview_arrow_position_ = intersection_ - preview_arrow_direction_ * arrow_length_;
    moveArrowPositionsAndOrientations( preview_arrow_position_, preview_arrow_direction_ );
    updateArrowSceneNodes();
    mouse_position_translation_ = { event.x, event.y };
    emit lookAtChanged();
    return Render;
  }

  return InteractionTool::processMouseEvent( event );
}

bool LookAtObjectTool::eventFilter( QObject *object, QEvent *event )
{
  // Mouse events and key presses are delivered through processMouseEvent() and processKeyEvent().
  // rviz has no tool callback for key releases though, so this filter observes the render panel's
  // events to catch the Shift release that returns from position to direction adaption. Key presses
  // are handled here as well to keep all key handling in one place.
  if ( event->type() == QEvent::KeyPress ) {
    auto *keyEvent = dynamic_cast<QKeyEvent *>( event );
    if ( keyEvent->key() == Qt::Key_S ) {
      // Saving only makes sense while teaching. In the use/look-at modes the config cannot be
      // edited (only rigidly placed), so S there would merely rewrite the same shape.
      if ( mode_ == MODE_TEACH_PREVIEW || mode_ == MODE_TEACH_ADAPT_CURRENT_X_Y_DIRECTION ) {
        saveArrowConfigToFile();
        mode_ = MODE_LOOK_AT;
      }
    } else if ( keyEvent->key() == Qt::Key_R ) {
      if ( readVectorsFromFile() )
        mode_ = MODE_USE_PREVIEW;
    } else if ( keyEvent->key() == Qt::Key_Shift ) {
      if ( mode_ == MODE_USE_ADAPT_DIRECTION ) {
        mode_ = MODE_USE_ADAPT_POSITION;
        mouse_position_translation_ = mouse_position_;
      }

    } else if ( keyEvent->key() == Qt::Key_Right ) {
      if ( !arrows_.empty() )
        selected_arrow_index_ = ( selected_arrow_index_ + 1 ) % arrows_.size();
      updateColors();
      emit lookAtChanged();
      return true; // prevent normal reaction to arrow press
    } else if ( keyEvent->key() == Qt::Key_Left ) {
      if ( !arrows_.empty() )
        selected_arrow_index_ = ( selected_arrow_index_ + arrows_.size() - 1 ) % arrows_.size();
      updateColors();
      emit lookAtChanged();
      return true; // prevent normal reaction to arrow press
    } else if ( keyEvent->key() == Qt::Key_Up && mode_ == MODE_USE_PREVIEW ) {
      updateFileName( true );
      readVectorsFromFile();
      return true;
    } else if ( keyEvent->key() == Qt::Key_Down && mode_ == MODE_USE_PREVIEW ) {
      updateFileName( false );
      readVectorsFromFile();
      return true;
    } else if ( keyEvent->key() == Qt::Key_Q ) {
      mode_ = MODE_TEACH_PREVIEW;
      arrows_.clear();
      selected_arrow_index_ = 0;
      emit lookAtChanged();
      updateStatus();
      return true;
    }
  } else if ( event->type() == QEvent::KeyRelease ) {
    auto *keyEvent = dynamic_cast<QKeyEvent *>( event );
    if ( keyEvent->key() == Qt::Key_Shift ) {
      if ( mode_ == MODE_USE_ADAPT_POSITION ) {
        mode_ = MODE_USE_ADAPT_DIRECTION;
        mouse_position_ = mouse_position_translation_;
      }
    }
  }
  updateStatus();
  return false;
}

void LookAtObjectTool::updateColors()
{
  for ( size_t i = 0; i < arrows_.size(); i++ ) {
    arrows_[i].arrow->setColor( 255.0 / 255.0, 210.0 / 255.0, 0, 1.0 );
    if ( i == selected_arrow_index_ ) {
      arrows_[i].arrow->setColor( Ogre::ColourValue::Blue );
    }
  }
}

void LookAtObjectTool::updateArrowSceneNodes()
{
  for ( LookAtArrow &state : arrows_ ) {
    state.arrow->setPosition( state.position );
    state.arrow->setDirection( state.direction );
    state.arrow->getSceneNode()->setVisible( true );
  }
}
void LookAtObjectTool::updateFileName( bool advance )
{
  const fs::path directory = configDirectory();
  if ( !fs::is_directory( directory ) ) {
    UI_LOG_ERROR_STREAM( "Look at object config directory does not exist: " << directory.string() );
    return;
  }
  std::vector<fs::path> file_paths;
  for ( const auto &entry : fs::directory_iterator( directory ) ) {
    file_paths.push_back( entry.path() );
  }
  if ( file_paths.empty() )
    return;

  // Sort the file paths alphabetically by their filenames
  std::sort( file_paths.begin(), file_paths.end(), []( const fs::path &a, const fs::path &b ) {
    return a.filename().string() < b.filename().string();
  } );

  const fs::path current_file = directory / name_property_->getStdString();
  size_t index = 0;
  for ( size_t i = 0; i < file_paths.size(); ++i ) {
    if ( file_paths[i] == current_file ) {
      index = i;
      break;
    }
  }
  const size_t next_index = advance ? ( index + 1 ) % file_paths.size()
                                    : ( index + file_paths.size() - 1 ) % file_paths.size();
  name_property_->setStdString( file_paths[next_index].filename().string() );
}

const LookAtObjectTool::LookAtArrow *LookAtObjectTool::selectedArrow() const
{
  if ( arrows_.empty() )
    return nullptr;
  return &arrows_[selected_arrow_index_];
}

void LookAtObjectTool::clampSelectedArrowIndex()
{
  if ( selected_arrow_index_ >= arrows_.size() )
    selected_arrow_index_ = arrows_.empty() ? 0 : arrows_.size() - 1;
}

QVector3D LookAtObjectTool::lookAtPosition() const
{
  const LookAtArrow *arrow = selectedArrow();
  if ( arrow == nullptr )
    return { 0, 0, 0 };
  return { arrow->position.x, arrow->position.y, arrow->position.z };
}

QVariantList LookAtObjectTool::lookAtMultiple() const
{
  QVariantList list;
  for ( const LookAtArrow &state : arrows_ ) {
    QVariantMap lookAt;
    lookAt.insert( "position", QVector3D{ state.position.x, state.position.y, state.position.z } );
    lookAt.insert( "orientation", directionToQuaternion( state.direction ) );
    list.push_back( lookAt );
  }
  return list;
}

QVector3D LookAtObjectTool::lookAtDirection() const
{
  const LookAtArrow *arrow = selectedArrow();
  if ( arrow == nullptr )
    return { 0, 0, 0 };
  return { arrow->direction.x, arrow->direction.y, arrow->direction.z };
}

QQuaternion LookAtObjectTool::lookAtOrientation() const
{
  const LookAtArrow *arrow = selectedArrow();
  const Ogre::Vector3 direction = arrow == nullptr ? Ogre::Vector3( 1, 0, 0 ) : arrow->direction;
  return directionToQuaternion( direction );
}

void LookAtObjectTool::directionToRotationMatrix( Ogre::Matrix3 &matrix,
                                                  const Ogre::Vector3 &direction )
{
  Ogre::Vector3 vec1;
  if ( abs( Ogre::Vector3( 0, 0, 1 ).dotProduct( direction ) ) < 0.95 ) {
    vec1 = Ogre::Vector3( 0, 0, 1 ).crossProduct( direction );
  } else if ( abs( Ogre::Vector3( 0, 1, 0 ).dotProduct( direction ) ) < 0.95 ) {
    vec1 = Ogre::Vector3( 0, 1, 0 ).crossProduct( direction );
  } else {
    vec1 = Ogre::Vector3( 1, 0, 0 ).crossProduct( direction );
  }
  vec1.normalise();
  Ogre::Vector3 vec2 = vec1.crossProduct( direction );
  vec2.normalise();
  matrix.FromAxes( direction, vec2, vec1 );
  if ( matrix.Determinant() < 0 ) {
    matrix.FromAxes( direction, -vec2, vec1 );
  }
}

void LookAtObjectTool::moveArrowPositionsAndOrientations( const Ogre::Vector3 &goal_position,
                                                          const Ogre::Vector3 &goal_direction )
{
  Ogre::Matrix3 turn_angle_rot;
  turn_angle_rot.FromAngleAxis( { 1, 0, 0 }, Ogre::Degree( turn_angle_ ) );
  Ogre::Matrix3 rot;

  directionToRotationMatrix( rot, goal_direction );

  rot = rot * turn_angle_rot;
  for ( LookAtArrow &state : arrows_ ) {
    state.direction = rot * state.original_direction;
    state.position = rot * state.original_position + goal_position;
  }
}

void LookAtObjectTool::moveArrowPositionsAndOrientations()
{
  if ( arrows_.empty() )
    return;
  // The first arrow defines the reference pose every other arrow is expressed relative to
  const Ogre::Vector3 reference_position = arrows_[0].position;
  Ogre::Matrix3 rot;
  directionToRotationMatrix( rot, arrows_[0].direction );
  const Ogre::Matrix3 rot_inv = rot.Inverse();
  for ( LookAtArrow &state : arrows_ ) {
    state.original_direction = rot_inv * state.direction;
    state.original_position = rot_inv * ( state.position - reference_position );
  }
}

void LookAtObjectTool::saveArrowConfigToFile()
{
  if ( arrows_.empty() )
    return;
  const fs::path config_dir = configDirectory();
  if ( config_dir.empty() )
    return;
  const fs::path config_file = config_dir / name_property_->getStdString();

  std::error_code error;
  fs::create_directories( config_file.parent_path(), error );
  if ( error ) {
    UI_LOG_ERROR_STREAM( "Failed to create directory " << config_file.parent_path().string() << ": "
                                                       << error.message() );
    return;
  }

  // Open the file for writing
  std::ofstream file( config_file );
  if ( !file.is_open() ) {
    UI_LOG_ERROR_STREAM( "Failed to open file for writing: " << config_file.string() );
    return;
  }
  moveArrowPositionsAndOrientations();

  // Write the normalized arrow positions and directions to the file
  for ( size_t i = 0; i < arrows_.size(); ++i ) {
    const LookAtArrow &state = arrows_[i];
    file << "Arrow " << i << ": " << state.original_position.x << " " << state.original_position.y
         << " " << state.original_position.z << " " << std::endl;
    file << "Direction " << i << ": " << state.original_direction.x << " "
         << state.original_direction.y << " " << state.original_direction.z << " " << std::endl;
  }

  UI_LOG_INFO_STREAM( "Config file saved: " << config_file.string() );
}

bool LookAtObjectTool::readVectorsFromFile()
{
  const fs::path config_dir = configDirectory();
  if ( config_dir.empty() )
    return false;
  const fs::path config_file = config_dir / name_property_->getStdString();
  // Open the file for reading
  std::ifstream file( config_file );
  if ( !file.is_open() ) {
    UI_LOG_ERROR_STREAM( "Failed to open file for reading: " << config_file.string() );
    return false;
  }
  // Read the vectors from the file
  std::vector<Ogre::Vector3> positions, directions;
  std::string line;
  while ( std::getline( file, line ) ) {
    // Parse the line to extract the values
    std::istringstream iss( line );
    std::string type;
    int index;
    std::string dummy;
    double x, y, z;

    // Determine if it's an arrow position or direction line
    iss >> type >> index >> dummy >> x >> y >> z;
    if ( type != "Arrow" && type != "Direction" ) {
      UI_LOG_ERROR_STREAM( "Invalid line in config file: " << line << " type: " << type
                                                           << " [must be 'Arrow' or 'Direction']" );
      continue;
    }
    if ( iss.fail() ) {
      UI_LOG_ERROR_STREAM( "Failed to parse vector from config file line: " << line );
      return false;
    }
    if ( type == "Arrow" ) {
      positions.emplace_back( x, y, z );
    } else {
      directions.emplace_back( x, y, z );
    }
  }

  if ( positions.size() != directions.size() ) {
    UI_LOG_ERROR_STREAM( "Config file " << config_file.string() << " has " << positions.size()
                                        << " arrow positions but " << directions.size()
                                        << " directions, ignoring it." );
    return false;
  }

  // Recreate arrows. The fixed frame pose starts out as the reference pose and is replaced as soon
  // as the configuration is placed on an object.
  arrows_.clear();
  for ( size_t i = 0; i < positions.size(); i++ ) {
    LookAtArrow &state = arrows_.emplace_back();
    state.original_position = positions[i];
    state.original_direction = directions[i];
    state.position = positions[i];
    state.direction = directions[i];
    state.arrow = createArrow( scene_manager_, state.position, state.direction, arrow_length_, 0.7 );
    state.arrow->getSceneNode()->setVisible( true );
  }
  selected_arrow_index_ = 0;
  updateColors();
  emit lookAtChanged();
  return true;
}

} // namespace hector_user_interface

#include <pluginlib/class_list_macros.hpp>

PLUGINLIB_EXPORT_CLASS( hector_user_interface::LookAtObjectTool, rviz_common::Tool )
