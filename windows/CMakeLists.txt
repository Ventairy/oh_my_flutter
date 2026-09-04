# The Flutter tooling requires Visual Studio with CMake 3.14 or later.
cmake_minimum_required(VERSION 3.14)

set(PROJECT_NAME "oh_my_flutter")
project(${PROJECT_NAME} LANGUAGES CXX)
cmake_policy(VERSION 3.14...3.25)

set(PLUGIN_NAME "oh_my_flutter_plugin")

list(APPEND PLUGIN_SOURCES
  "native_selectable_text.g.cpp"
  "native_selectable_text_menu_host.cpp"
  "native_selectable_text_menu_host.h"
  "oh_my_flutter_plugin.cpp"
  "oh_my_flutter_plugin.h"
)

add_library(${PLUGIN_NAME} SHARED
  "include/oh_my_flutter/oh_my_flutter_plugin_c_api.h"
  "oh_my_flutter_plugin_c_api.cpp"
  ${PLUGIN_SOURCES}
)

apply_standard_settings(${PLUGIN_NAME})
set_target_properties(${PLUGIN_NAME} PROPERTIES CXX_VISIBILITY_PRESET hidden)
target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL NOMINMAX)
target_include_directories(${PLUGIN_NAME} INTERFACE
  "${CMAKE_CURRENT_SOURCE_DIR}/include")
target_link_libraries(${PLUGIN_NAME} PRIVATE flutter flutter_wrapper_plugin user32)

set(oh_my_flutter_bundled_libraries
  ""
  PARENT_SCOPE
)

if (${include_${PROJECT_NAME}_tests})
  set(TEST_RUNNER "${PROJECT_NAME}_test")
  enable_testing()

  include(FetchContent)
  FetchContent_Declare(
    googletest
    URL https://github.com/google/googletest/archive/v1.18.0.zip
  )
  set(gtest_force_shared_crt ON CACHE BOOL "" FORCE)
  set(INSTALL_GTEST OFF CACHE BOOL "Disable installation of googletest" FORCE)
  FetchContent_MakeAvailable(googletest)

  add_executable(${TEST_RUNNER}
    "test/native_selectable_text_menu_host_test.cpp"
    "native_selectable_text.g.cpp"
    "native_selectable_text_menu_host.cpp"
    "native_selectable_text_menu_host.h"
  )
  apply_standard_settings(${TEST_RUNNER})
  target_compile_definitions(${TEST_RUNNER} PRIVATE NOMINMAX)
  target_include_directories(${TEST_RUNNER} PRIVATE
    "${CMAKE_CURRENT_SOURCE_DIR}")
  target_link_libraries(${TEST_RUNNER} PRIVATE flutter_wrapper_plugin user32)
  target_link_libraries(${TEST_RUNNER} PRIVATE gtest_main gmock)
  add_custom_command(TARGET ${TEST_RUNNER} POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
    "${FLUTTER_LIBRARY}" $<TARGET_FILE_DIR:${TEST_RUNNER}>
  )

  include(GoogleTest)
  gtest_discover_tests(${TEST_RUNNER})
endif()
