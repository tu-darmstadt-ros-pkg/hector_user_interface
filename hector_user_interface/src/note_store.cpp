//
// Created by Stefan Fabian on 27.07.26.
//

#include "hector_user_interface/note_store.h"

#include <QDir>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QSaveFile>

namespace hector_user_interface
{

namespace
{
constexpr int kNotesFileVersion = 1;

bool parseNote( const QJsonValue &value, Note &note )
{
  if ( !value.isObject() )
    return false;
  const QJsonObject obj = value.toObject();
  if ( !obj["id"].isString() || !obj["frame"].isString() || !obj["position"].isArray() )
    return false;
  const QJsonArray position = obj["position"].toArray();
  if ( position.size() != 3 || !position[0].isDouble() || !position[1].isDouble() ||
       !position[2].isDouble() )
    return false;
  note.id = obj["id"].toString();
  note.frame = obj["frame"].toString();
  note.position =
      Ogre::Vector3( position[0].toDouble(), position[1].toDouble(), position[2].toDouble() );
  note.icon = obj["icon"].toString();
  note.color = obj["color"].toString();
  note.text = obj["text"].toString();
  return true;
}
} // namespace

QString expandPath( const QString &path )
{
  if ( path.startsWith( "~/" ) )
    return QDir::homePath() + path.mid( 1 );
  return path;
}

NoteFile loadNotes( const QString &path )
{
  NoteFile result;
  QFile file( expandPath( path ) );
  if ( !file.exists() )
    return result;
  if ( !file.open( QIODevice::ReadOnly ) ) {
    result.error = "Could not read notes file '" + path + "'.";
    return result;
  }
  QJsonParseError error;
  const QJsonDocument document = QJsonDocument::fromJson( file.readAll(), &error );
  if ( error.error != QJsonParseError::NoError || !document.isObject() ) {
    result.error = "Notes file '" + path + "' is not valid JSON.";
    return result;
  }
  const QJsonObject root = document.object();
  if ( root["version"].toInt() > kNotesFileVersion ) {
    result.error = "Notes file '" + path + "' was written by a newer version.";
    return result;
  }
  for ( const QJsonValue &value : root["notes"].toArray() ) {
    Note note;
    if ( !parseNote( value, note ) ) {
      qWarning( "Skipping malformed note entry in '%s'.", qPrintable( path ) );
      continue;
    }
    result.notes.push_back( note );
  }
  return result;
}

bool saveNotes( const QString &path, const std::vector<Note> &notes )
{
  const QString expanded = expandPath( path );
  if ( !QDir().mkpath( QFileInfo( expanded ).absolutePath() ) )
    return false;
  QJsonArray note_array;
  for ( const Note &note : notes ) {
    QJsonObject obj;
    obj["id"] = note.id;
    obj["frame"] = note.frame;
    obj["position"] = QJsonArray{ note.position.x, note.position.y, note.position.z };
    obj["icon"] = note.icon;
    obj["color"] = note.color;
    obj["text"] = note.text;
    note_array.append( obj );
  }
  QJsonObject root;
  root["version"] = kNotesFileVersion;
  root["notes"] = note_array;
  QSaveFile file( expanded );
  if ( !file.open( QIODevice::WriteOnly ) )
    return false;
  file.write( QJsonDocument( root ).toJson() );
  return file.commit();
}
} // namespace hector_user_interface
