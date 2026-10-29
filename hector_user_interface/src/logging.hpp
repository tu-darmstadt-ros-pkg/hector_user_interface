#ifndef HECTOR_USER_INTERFACE_LOGGING_HPP
#define HECTOR_USER_INTERFACE_LOGGING_HPP

#include <rclcpp/logging.hpp>

#define UI_LOG_DEBUG( ... )                                                                        \
  RCLCPP_DEBUG( rclcpp::get_logger( "hector_user_interface" ), __VA_ARGS__ )
#define UI_LOG_INFO( ... ) RCLCPP_INFO( rclcpp::get_logger( "hector_user_interface" ), __VA_ARGS__ )
#define UI_LOG_WARN( ... ) RCLCPP_WARN( rclcpp::get_logger( "hector_user_interface" ), __VA_ARGS__ )
#define UI_LOG_ERROR( ... )                                                                        \
  RCLCPP_ERROR( rclcpp::get_logger( "hector_user_interface" ), __VA_ARGS__ )
#define UI_LOG_FATAL( ... )                                                                        \
  RCLCPP_FATAL( rclcpp::get_logger( "hector_user_interface" ), __VA_ARGS__ )

#define UI_LOG_DEBUG_STREAM( ... )                                                                 \
  RCLCPP_DEBUG_STREAM( rclcpp::get_logger( "hector_user_interface" ), __VA_ARGS__ )
#define UI_LOG_INFO_STREAM( ... )                                                                  \
  RCLCPP_INFO_STREAM( rclcpp::get_logger( "hector_user_interface" ), __VA_ARGS__ )
#define UI_LOG_WARN_STREAM( ... )                                                                  \
  RCLCPP_WARN_STREAM( rclcpp::get_logger( "hector_user_interface" ), __VA_ARGS__ )
#define UI_LOG_ERROR_STREAM( ... )                                                                 \
  RCLCPP_ERROR_STREAM( rclcpp::get_logger( "hector_user_interface" ), __VA_ARGS__ )
#define UI_LOG_FATAL_STREAM( ... )                                                                 \
  RCLCPP_FATAL_STREAM( rclcpp::get_logger( "hector_user_interface" ), __VA_ARGS__ )

#endif // HECTOR_USER_INTERFACE_LOGGING_HPP
