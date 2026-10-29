cmake_minimum_required(VERSION 3.15)
project(hector_user_interface_msgs)

find_package(ament_cmake REQUIRED)
find_package(rosidl_default_generators REQUIRED)

rosidl_generate_interfaces(
  ${PROJECT_NAME}
  "action/OperatorPrompt.action"
  ADD_LINTER_TESTS)

ament_export_dependencies(rosidl_default_runtime)

ament_package()
