cmake_minimum_required(VERSION 3.16)
project(hector_user_interface_launch)

# Find necessary packages
find_package(ament_cmake REQUIRED)

# Register environment hooks
ament_environment_hooks(20.register_tuda_wss.dsv.in)

# Install directories
install(DIRECTORY
  launch
  media
  rviz
  DESTINATION share/${PROJECT_NAME}
)
# Install scripts separately with source permissions as source permissions
# and symlink install conflict, so they would be copied instead of symlinked
install(DIRECTORY
  scripts
  DESTINATION share/${PROJECT_NAME}
  USE_SOURCE_PERMISSIONS # executable scripts stay executable after installation
)

# Mark the package as an ament package
ament_package()
