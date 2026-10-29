//
// Created by Stefan Fabian on 27.07.26.
//

#ifndef HECTOR_USER_INTERFACE_NOTE_TOOL_H
#define HECTOR_USER_INTERFACE_NOTE_TOOL_H

#include "hector_user_interface/note_store.h"

#include <rviz_default_plugins/tools/interaction/interaction_tool.hpp>

#include <QPoint>
#include <QVariantMap>
#include <memory>
#include <vector>

namespace rviz_common::properties
{
class BoolProperty;
class StringProperty;
class TfFrameProperty;
} // namespace rviz_common::properties

namespace rviz_rendering
{
class ViewportProjectionFinder;
} // namespace rviz_rendering

namespace hector_user_interface
{

/*!
 * Places a note at a clicked 3D point and owns the note model and its persistence.
 * The notes are displayed and edited in QML (ui/notes/NoteMarkers.qml).
 */
class NoteTool : public rviz_default_plugins::tools::InteractionTool
{
  Q_OBJECT
  //! Notes as QVariantMaps { id, frame, position (note-frame coords), icon, color, text }.
  Q_PROPERTY( QVariantList notes READ notes NOTIFY notesChanged )
  Q_PROPERTY( bool notesReadOnly READ notesReadOnly NOTIFY notesErrorChanged )
  //! Empty when everything is fine, otherwise the reason, shown verbatim in the popup.
  Q_PROPERTY( QString notesError READ notesError NOTIFY notesErrorChanged )
public:
  NoteTool();

  void activate() override;

  int processMouseEvent( rviz_common::ViewportMouseEvent &event ) override;

  QVariantList notes() const;

  bool notesReadOnly() const;

  QString notesError() const;

  //! Inserts the note if its id is unknown (a note from notePlaced), otherwise replaces the
  //! icon, color and text of the stored note.
  Q_INVOKABLE void saveNote( const QVariantMap &note );

  //! Erases the note with the same id.
  Q_INVOKABLE void removeNote( const QVariantMap &note );

  Q_INVOKABLE void clearNotes();

  //! @return { position: QVector3D (scene/fixed-frame), valid: bool }
  Q_INVOKABLE QVariantMap scenePosition( const QVariantMap &note ) const;

  //! @return { eye, focus: QVector3D (scene/fixed-frame), valid: bool } of a camera looking at
  //! the note from a fixed distance on the line from the current camera position to the note.
  Q_INVOKABLE QVariantMap viewPose( const QVariantMap &note ) const;

signals:

  //! Notes were added, edited or removed.
  void notesChanged();

  //! A click resolved to a new note. It is not part of notes until passed to saveNote.
  void notePlaced( QVariantMap note );

  //! Emitted periodically so scene positions follow note frames moving in the fixed frame.
  void noteTransformsChanged();

  void notesErrorChanged();

private Q_SLOTS:
  //! Full reload from the notes file; re-evaluates read-only and error.
  void loadFromFile();

protected:
  void onInitialize() override;

  /// Shows the tool's control guide in the status bar.
  void updateStatus();

private:
  void placeNote( const rviz_common::ViewportMouseEvent &event );
  //! Writes the notes file unless the session is read-only.
  void persist();
  void setNotesError( const QString &error );
  //! Transforms the note's position into the fixed frame. False if its frame has no transform.
  bool lookupScenePosition( const QVariantMap &note, Ogre::Vector3 &scene_position ) const;

  std::vector<Note> notes_;
  std::shared_ptr<rviz_rendering::ViewportProjectionFinder> projection_finder_;
  rviz_common::properties::BoolProperty *raycast3d_property_ = nullptr;
  rviz_common::properties::TfFrameProperty *note_frame_property_ = nullptr;
  rviz_common::properties::StringProperty *notes_file_property_ = nullptr;
  QPoint press_position_;
  bool press_armed_ = false;
  bool notes_read_only_ = false;
  QString notes_error_;
};
} // namespace hector_user_interface

#endif // HECTOR_USER_INTERFACE_NOTE_TOOL_H
