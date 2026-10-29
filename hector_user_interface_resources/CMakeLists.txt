cmake_minimum_required(VERSION 3.5.0)
project(hector_user_interface_resources VERSION 1.0.0)

find_package(ament_cmake REQUIRED)


ament_environment_hooks(register_hector_user_interface_resources.dsv.in)

#############
## Install ##
#############

install(DIRECTORY Hector DESTINATION share/${PROJECT_NAME})

ament_package()
