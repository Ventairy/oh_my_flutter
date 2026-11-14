cmake_minimum_required(VERSION 3.22.1)
project(omf_motion_particles C)

add_library(omf_motion_particles SHARED particle_geometry.c particle_geometry_jni.c)
set_target_properties(omf_motion_particles PROPERTIES C_STANDARD 11 C_STANDARD_REQUIRED YES)
target_compile_options(omf_motion_particles PRIVATE -O3 -ffp-contract=off -Wall -Wextra -Werror)
