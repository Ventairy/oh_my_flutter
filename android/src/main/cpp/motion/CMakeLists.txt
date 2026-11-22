cmake_minimum_required(VERSION 3.22.1)
project(omf_motion_particles C)

add_library(omf_motion_particles SHARED particle_geometry.c particle_geometry_jni.c)
set_target_properties(omf_motion_particles PROPERTIES C_STANDARD 11 C_STANDARD_REQUIRED YES)
target_compile_options(omf_motion_particles PRIVATE -O3 -ffp-contract=off -Wall -Wextra -Werror)

if(ANDROID_ABI STREQUAL "armeabi-v7a")
  target_sources(omf_motion_particles PRIVATE particle_frozen_pose.c)
  # Match Dart's separate libm calls and unfused arithmetic.
  set_source_files_properties(particle_frozen_pose.c PROPERTIES COMPILE_OPTIONS "-fno-builtin-sin;-fno-builtin-cos")
  target_link_libraries(omf_motion_particles PRIVATE m)
endif()
