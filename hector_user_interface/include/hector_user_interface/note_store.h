//
// Created by Stefan Fabian on 27.07.26.
//

#ifndef HECTOR_USER_INTERFACE_NOTE_STORE_H
#define HECTOR_USER_INTERFACE_NOTE_STORE_H

#include <OgreVector.h>
#include <QString>
#include <vector>

namespace hector_user_interface
{

//! A world annotation placed by the operator.
struct Note {
  QString id;                                   //!< Unique id, QUuid without braces.
  QString frame;                                //!< TF frame the position is expressed in.
  Ogre::Vector3 position = Ogre::Vector3::ZERO; //!< Position in frame.
  QString icon;                                 //!< Style.icons key; empty = unset.
  QString color;                                //!< "#rrggbb"; empty = unset.
  QString text;
};

struct NoteFile {
  std::vector<Note> notes;
  //! Empty if the file was loaded or does not exist, otherwise why it could not be loaded.
  QString error;
};

//! Replaces a leading "~/" with QDir::homePath(). Everything else is passed through.
QString expandPath( const QString &path );

//! Loads the notes from the given file. The path is expanded; a load never creates anything.
//! Malformed entries are skipped, unknown keys ignored.
NoteFile loadNotes( const QString &path );

//! Writes the notes to the given (expanded) path, creating the parent directory if necessary.
//! Writes through QSaveFile, so a crash mid-write cannot truncate the file.
//! @return False on any failure.
bool saveNotes( const QString &path, const std::vector<Note> &notes );
} // namespace hector_user_interface

#endif // HECTOR_USER_INTERFACE_NOTE_STORE_H
