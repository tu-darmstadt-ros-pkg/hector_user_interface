//
// Created by Stefan Fabian on 27.07.26.
//

#include <hector_user_interface/note_store.h>

#include <gtest/gtest.h>

#include <QDir>
#include <QFile>
#include <QTemporaryDir>

using namespace hector_user_interface;

namespace
{

void writeFile( const QString &path, const QByteArray &content )
{
  QFile file( path );
  ASSERT_TRUE( file.open( QIODevice::WriteOnly ) );
  file.write( content );
}
} // namespace

TEST( NoteStore, roundTrip )
{
  QTemporaryDir dir;
  const QString path = dir.filePath( "notes.json" );
  std::vector<Note> notes;
  notes.push_back( { "id-1", "map", Ogre::Vector3( 1.5f, -2.25f, 0.75f ), "info", "#ffcc00",
                     "blocked stairwell" } );
  notes.push_back( { "id-2", "world", Ogre::Vector3( -3, 0, 12.5f ), "", "",
                     QString::fromUtf8( "Tür zu!\n\"Ventil\" öffnen…\nzweite Zeile" ) } );
  ASSERT_TRUE( saveNotes( path, notes ) );

  const NoteFile loaded = loadNotes( path );
  EXPECT_TRUE( loaded.error.isEmpty() );
  ASSERT_EQ( loaded.notes.size(), notes.size() );
  for ( size_t i = 0; i < notes.size(); ++i ) {
    EXPECT_EQ( loaded.notes[i].id, notes[i].id );
    EXPECT_EQ( loaded.notes[i].frame, notes[i].frame );
    EXPECT_EQ( loaded.notes[i].position, notes[i].position );
    EXPECT_EQ( loaded.notes[i].icon, notes[i].icon );
    EXPECT_EQ( loaded.notes[i].color, notes[i].color );
    EXPECT_EQ( loaded.notes[i].text, notes[i].text );
  }
}

TEST( NoteStore, saveCreatesDirectory )
{
  QTemporaryDir dir;
  const QString path = dir.filePath( "does/not/exist/notes.json" );
  EXPECT_TRUE( saveNotes( path, {} ) );
  EXPECT_TRUE( QFile::exists( path ) );
}

TEST( NoteStore, expandPath )
{
  EXPECT_EQ( expandPath( "~/.ros/notes.json" ), QDir::homePath() + "/.ros/notes.json" );
  EXPECT_EQ( expandPath( "/absolute/notes.json" ), "/absolute/notes.json" );
  EXPECT_EQ( expandPath( "relative/notes.json" ), "relative/notes.json" );
  EXPECT_EQ( expandPath( "some/~/notes.json" ), "some/~/notes.json" );
}

TEST( NoteStore, missingFile )
{
  QTemporaryDir dir;
  const NoteFile loaded = loadNotes( dir.filePath( "nope.json" ) );
  EXPECT_TRUE( loaded.error.isEmpty() );
  EXPECT_TRUE( loaded.notes.empty() );
}

TEST( NoteStore, malformedEntriesAreSkipped )
{
  QTemporaryDir dir;
  const QString path = dir.filePath( "notes.json" );
  writeFile( path, R"({"version": 1, "notes": [
    {"id": "good", "frame": "map", "position": [1.0, 2.0, 3.0], "icon": "flag", "color": "", "text": ""},
    {"id": "no-position", "frame": "map"},
    {"id": "bad-position", "frame": "map", "position": "front door"},
    42
  ]})" );
  const NoteFile loaded = loadNotes( path );
  EXPECT_TRUE( loaded.error.isEmpty() );
  ASSERT_EQ( loaded.notes.size(), 1u );
  EXPECT_EQ( loaded.notes[0].id, "good" );
}

TEST( NoteStore, corruptFile )
{
  QTemporaryDir dir;
  const QString path = dir.filePath( "notes.json" );
  writeFile( path, "this is not json {" );
  const NoteFile loaded = loadNotes( path );
  EXPECT_FALSE( loaded.error.isEmpty() );
  EXPECT_TRUE( loaded.notes.empty() );
}

TEST( NoteStore, incompatibleVersion )
{
  QTemporaryDir dir;
  const QString path = dir.filePath( "notes.json" );
  writeFile( path, R"({"version": 99, "notes": []})" );
  const NoteFile loaded = loadNotes( path );
  EXPECT_FALSE( loaded.error.isEmpty() );
  EXPECT_TRUE( loaded.notes.empty() );
}
