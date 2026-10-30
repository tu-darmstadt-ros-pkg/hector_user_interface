//
// Created by Stefan Fabian on 07.02.20.
//

#include "hector_user_interface/user_interface.h"

#include <ament_index_cpp/get_package_share_path.hpp>

namespace hector_user_interface
{
QString UserInterface::getPathToQml()
{
  const auto path = ament_index_cpp::get_package_share_path( "hector_user_interface" ) / "ui/main.qml";
  return QString::fromStdString( path.string() );
}
} // namespace hector_user_interface

#include <pluginlib/class_list_macros.hpp>

PLUGINLIB_EXPORT_CLASS( hector_user_interface::UserInterface, rviz_common::Display )