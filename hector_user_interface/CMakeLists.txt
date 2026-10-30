cmake_minimum_required(VERSION 3.16)
project(hector_user_interface VERSION 1.0.0)
set(CMAKE_CXX_STANDARD 17)

find_package(ament_cmake REQUIRED)
find_package(hector_rviz_overlay REQUIRED)
find_package(rclcpp REQUIRED)
find_package(resource_retriever REQUIRED)
find_package(rviz_common REQUIRED)
find_package(rviz_default_plugins REQUIRED)
find_package(rviz_rendering REQUIRED)
find_package(moveit_ros_visualization REQUIRED)

set(CMAKE_AUTOMOC ON)

###########
## Build ##
###########

add_library(${PROJECT_NAME} SHARED
  include/hector_user_interface/look_at_tool.h
  include/hector_user_interface/look_at_object_tool.h
  include/hector_user_interface/note_store.h
  include/hector_user_interface/note_tool.h
  include/hector_user_interface/user_interface.h
  include/hector_user_interface/waypoint_tool.h
  include/hector_user_interface/waypoint.h
  src/look_at_tool.cpp
  src/look_at_object_tool.cpp
  src/note_store.cpp
  src/note_tool.cpp
  src/user_interface.cpp
  src/waypoint_tool.cpp
  src/waypoint.cpp
)
target_include_directories(${PROJECT_NAME} PUBLIC
  $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
  $<INSTALL_INTERFACE:include>
)
target_link_libraries(${PROJECT_NAME} PUBLIC
  hector_rviz_overlay::hector_rviz_overlay
  moveit_ros_visualization::moveit_rviz_plugin_render_tools
  rclcpp::rclcpp
  resource_retriever::resource_retriever
  rviz_common::rviz_common
  rviz_default_plugins::rviz_default_plugins
  rviz_rendering::rviz_rendering
)
# Causes the visibility macros to use dllexport rather than dllimport,
# which is appropriate when building the dll but not consuming it.
target_compile_definitions(${PROJECT_NAME} PRIVATE "RVIZ_DEFAULT_PLUGINS_BUILDING_LIBRARY")

# prevent pluginlib from using boost
target_compile_definitions(${PROJECT_NAME} PUBLIC "PLUGINLIB__DISABLE_BOOST_FUNCTIONS")

pluginlib_export_plugin_description_file(rviz_common rviz_common_plugins.xml)

#############
## Testing ##
#############

if(BUILD_TESTING)
  find_package(ament_cmake_gtest REQUIRED)
  find_package(Qt6 REQUIRED COMPONENTS Core)
  ament_add_gtest(test_notes test/test_note_store.cpp src/note_store.cpp)
  if(TARGET test_notes) # ament_add_gtest is a no-op when gtest is missing
    target_include_directories(test_notes PRIVATE include)
    # Plain signature: ament_add_gtest already used it for this target, mixing is an error.
    target_link_libraries(test_notes Qt6::Core rviz_ogre_vendor::OgreMain)
  endif()
endif()

#############
## Install ##
#############

install(TARGETS ${PROJECT_NAME}
  EXPORT export_${PROJECT_NAME}
  LIBRARY DESTINATION lib
  ARCHIVE DESTINATION lib
  RUNTIME DESTINATION bin
  INCLUDES DESTINATION include
)

install(DIRECTORY include/ DESTINATION include)
install(DIRECTORY icons media ui DESTINATION share/${PROJECT_NAME})
install(FILES rviz_common_plugins.xml DESTINATION share/${PROJECT_NAME})

#############
## Export ##
#############

# ament_export_dependencies(hector_rviz_overlay rclcpp rviz_common rviz_default_plugins rviz_rendering)
# ament_export_include_directories(include)
# ament_export_libraries(${PROJECT_NAME})
ament_export_targets(export_${PROJECT_NAME})
ament_package()
