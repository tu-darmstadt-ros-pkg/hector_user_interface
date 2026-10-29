//
// Created by Stefan Fabian on 07.02.20.
//

#ifndef HECTOR_USER_INTERFACE_USER_INTERFACE_H
#define HECTOR_USER_INTERFACE_USER_INTERFACE_H

#include <hector_rviz_overlay/displays/qml_overlay_display.hpp>

namespace hector_user_interface
{

class UserInterface : public hector_rviz_overlay::QmlOverlayDisplay
{
  Q_OBJECT
protected:
  QString getPathToQml() override;
};
} // namespace hector_user_interface

#endif // HECTOR_USER_INTERFACE_USER_INTERFACE_H
