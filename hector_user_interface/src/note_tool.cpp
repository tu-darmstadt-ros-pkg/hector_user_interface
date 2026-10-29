//
// Created by Stefan Fabian on 27.07.26.
//

#include "hector_user_interface/note_tool.h"
#include "logging.hpp"

#include <rviz_common/display_context.hpp>
#include <rviz_common/frame_manager_iface.hpp>
#include <rviz_common/interaction/view_picker.hpp>
#include <rviz_common/properties/bool_property.hpp>
#include <rviz_common/properties/string_property.hpp>
#include <rviz_common/properties/tf_frame_property.hpp>
#include <rviz_common/render_panel.hpp>
#include <rviz_common/view_controller.hpp>
#include <rviz_common/view_manager.hpp>
#include <rviz_common/viewport_mouse_event.hpp>
#include <rviz_rendering/viewport_projection_finder.hpp>

#include <OgreCamera.h>
#include <OgreQuaternion.h>
#include <QTimer>
#include <QUuid>
#include <QVector3D>
#include <algorithm>

namespace hector_user_interface
{

namespace
{
constexpr int kClickMaxTravelPixels = 3;
//! Eye to note distance when moving the camera to a note, sqrt(4^2 + 4^2)
constexpr float kViewDistance = 5.66f;

QVector3D toQt( const Ogre::Vector3 &v ) { return { v.x, v.y, v.z }; }

Ogre::Vector3 toOgre( const QVector3D &v ) { return { v.x(), v.y(), v.z() }; }

QVariantMap toVariantMap( const Note &note )
{
  QVariantMap map;
  map.insert( "id", note.id );
  map.insert( "frame", note.frame );
  map.insert( "position", toQt( note.position ) );
  map.insert( "icon", note.icon );
  map.insert( "color", note.color );
  map.insert( "text", note.text );
  return map;
}

std::vector<Note>::iterator findNote( std::vector<Note> &notes, const QVariantMap &note )
{
  const QString id = note["id"].toString();
  return std::find_if( notes.begin(), notes.end(),
                       [&id]( const Note &existing ) { return existing.id == id; } );
}
} // namespace

NoteTool::NoteTool() : InteractionTool()
{
  projection_finder_ = std::make_shared<rviz_rendering::ViewportProjectionFinder>();
  shortcut_key_ = 'n';
  using namespace rviz_common::properties;
  raycast3d_property_ = new BoolProperty(
      "3D Raycast", true,
      "If true, will use scene manager to find intersection with compatible displayed entities. "
      "If false, will only check for intersection with ground plane.",
      this->getPropertyContainer() );
  note_frame_property_ = new TfFrameProperty(
      "Note Frame", TfFrameProperty::FIXED_FRAME_STRING,
      "The TF frame new notes are stored in. Resolved once per note, so later fixed frame "
      "changes do not move existing notes.",
      this->getPropertyContainer(), nullptr, true );
  notes_file_property_ =
      new StringProperty( "Notes File", "~/.ros/hector_user_interface/notes.json",
                          "The JSON file the notes are loaded from and saved to.",
                          this->getPropertyContainer(), SLOT( loadFromFile() ), this );
}

void NoteTool::onInitialize()
{
  InteractionTool::onInitialize();
  note_frame_property_->setFrameManager( context_->getFrameManager() );
  loadFromFile();
  auto *transform_timer = new QTimer( this );
  connect( transform_timer, &QTimer::timeout, this, &NoteTool::noteTransformsChanged );
  transform_timer->start( 100 );
}

void NoteTool::activate()
{
  InteractionTool::activate();
  updateStatus();
}

void NoteTool::updateStatus()
{
  setStatus( "<b>Left-Click:</b> Place note.  <b>Hold Ctrl:</b> Move camera." );
}

int NoteTool::processMouseEvent( rviz_common::ViewportMouseEvent &event )
{
  // Holding Ctrl leaves every event to the interaction tool so the camera can be moved.
  bool place = false;
  if ( event.leftDown() ) {
    press_position_ = QPoint( event.x, event.y );
    press_armed_ = !event.control();
  } else if ( event.leftUp() ) {
    const QPoint travel = QPoint( event.x, event.y ) - press_position_;
    // Disarmed so a double-click's second release places nothing. Focus is read before
    // delegating updates it, so clicks on interactive objects reach the object.
    place = press_armed_ && !event.control() &&
            QPoint::dotProduct( travel, travel ) <= kClickMaxTravelPixels * kClickMaxTravelPixels &&
            focused_object_.lock() == nullptr;
    press_armed_ = false;
  }
  // Always delegated: the view controller clears its drag state on release only.
  const int flags = InteractionTool::processMouseEvent( event );
  updateStatus();
  if ( place )
    placeNote( event );
  return flags;
}

void NoteTool::placeNote( const rviz_common::ViewportMouseEvent &event )
{
  Ogre::Vector3 intersection;
  bool have_point =
      raycast3d_property_->getBool() &&
      context_->getViewPicker()->get3DPoint( event.panel, event.x, event.y, intersection );
  if ( !have_point )
    std::tie( have_point, intersection ) = projection_finder_->getViewportPointProjectionOnXYPlane(
        event.panel->getRenderWindow(), event.x, event.y );
  if ( !have_point ) {
    UI_LOG_WARN( "Cannot place note: nothing under the cursor to place it on." );
    return;
  }
  const QString note_frame = note_frame_property_->getFrame();
  Ogre::Vector3 frame_position;
  Ogre::Quaternion frame_orientation;
  if ( !context_->getFrameManager()->getTransform( note_frame.toStdString(), frame_position,
                                                   frame_orientation ) ) {
    UI_LOG_WARN( "Cannot place note: no transform for the note frame '%s'. Change 'Note Frame' "
                 "in the tool properties.",
                 qPrintable( note_frame ) );
    return;
  }
  Note note;
  note.id = QUuid::createUuid().toString( QUuid::WithoutBraces );
  note.frame = note_frame;
  note.position = frame_orientation.Inverse() * ( intersection - frame_position );
  emit notePlaced( toVariantMap( note ) );
}

QVariantList NoteTool::notes() const
{
  QVariantList result;
  for ( const Note &note : notes_ ) { result.push_back( toVariantMap( note ) ); }
  return result;
}

bool NoteTool::notesReadOnly() const { return notes_read_only_; }

QString NoteTool::notesError() const { return notes_error_; }

void NoteTool::saveNote( const QVariantMap &note )
{
  auto it = findNote( notes_, note );
  if ( it == notes_.end() ) {
    Note added;
    added.id = note["id"].toString();
    added.frame = note["frame"].toString();
    added.position = toOgre( note["position"].value<QVector3D>() );
    it = notes_.insert( notes_.end(), added );
  }
  it->icon = note["icon"].toString();
  it->color = note["color"].toString();
  it->text = note["text"].toString();
  emit notesChanged();
  persist();
}

void NoteTool::removeNote( const QVariantMap &note )
{
  auto it = findNote( notes_, note );
  if ( it == notes_.end() )
    return;
  notes_.erase( it );
  emit notesChanged();
  persist();
}

void NoteTool::clearNotes()
{
  if ( notes_.empty() )
    return;
  notes_.clear();
  emit notesChanged();
  persist();
}

QVariantMap NoteTool::scenePosition( const QVariantMap &note ) const
{
  Ogre::Vector3 position;
  if ( !lookupScenePosition( note, position ) )
    return { { "valid", false } };
  return { { "valid", true }, { "position", toQt( position ) } };
}

QVariantMap NoteTool::viewPose( const QVariantMap &note ) const
{
  rviz_common::ViewController *view = context_->getViewManager()->getCurrent();
  Ogre::Vector3 focus;
  if ( view == nullptr || !lookupScenePosition( note, focus ) )
    return { { "valid", false } };
  const Ogre::Camera *camera = view->getCamera();
  Ogre::Vector3 direction = focus - camera->getDerivedPosition();
  // Approach along the line from the camera so it neither passes the note nor swings around it.
  if ( direction.normalise() < 1e-3f )
    direction = camera->getDerivedDirection();
  return { { "valid", true },
           { "focus", toQt( focus ) },
           { "eye", toQt( focus - direction * kViewDistance ) } };
}

void NoteTool::loadFromFile()
{
  NoteFile file = loadNotes( notes_file_property_->getString() );
  notes_ = std::move( file.notes );
  // A file this build cannot read must not be overwritten.
  notes_read_only_ = !file.error.isEmpty();
  notes_error_.clear();
  if ( notes_read_only_ ) {
    notes_error_ = file.error + " Notes are read-only in this session.";
    UI_LOG_ERROR( "%s", qPrintable( notes_error_ ) );
  }
  emit notesErrorChanged();
  emit notesChanged();
}

void NoteTool::persist()
{
  if ( notes_read_only_ )
    return;
  if ( saveNotes( notes_file_property_->getString(), notes_ ) )
    setNotesError( {} );
  else
    setNotesError( "Could not write notes file '" + notes_file_property_->getString() + "'." );
}

void NoteTool::setNotesError( const QString &error )
{
  if ( error == notes_error_ )
    return;
  notes_error_ = error;
  emit notesErrorChanged();
}

bool NoteTool::lookupScenePosition( const QVariantMap &note, Ogre::Vector3 &scene_position ) const
{
  Ogre::Vector3 frame_position;
  Ogre::Quaternion frame_orientation;
  if ( !context_->getFrameManager()->getTransform( note["frame"].toString().toStdString(),
                                                   frame_position, frame_orientation ) )
    return false;
  scene_position = frame_orientation * toOgre( note["position"].value<QVector3D>() ) + frame_position;
  return true;
}

} // namespace hector_user_interface

#include <pluginlib/class_list_macros.hpp>

PLUGINLIB_EXPORT_CLASS( hector_user_interface::NoteTool, rviz_common::Tool )
