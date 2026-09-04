cmake_minimum_required(VERSION 3.16)
project(kelvra_package_actions_native_fixture LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

add_library(kelvra_package_actions_native_fixture MODULE src/package.cpp)
target_include_directories(kelvra_package_actions_native_fixture PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}")
set_target_properties(kelvra_package_actions_native_fixture PROPERTIES PREFIX "" OUTPUT_NAME "package")
