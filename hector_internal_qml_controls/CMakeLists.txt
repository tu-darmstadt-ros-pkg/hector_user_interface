cmake_minimum_required(VERSION 3.16)
project(hector_internal_qml_controls VERSION 1.0.0)

find_package(ament_cmake REQUIRED)

ament_environment_hooks(register_hector_internal_qml_controls.dsv.in)

#############
## Install ##
#############

install(DIRECTORY Hector DESTINATION share/${PROJECT_NAME})

ament_package()
