cmake_minimum_required(VERSION 3.15)
project(template_cpp LANGUAGES CXX)

# # 启用 Conan 生成的配置（关键！）
# include(${CMAKE_BINARY_DIR}/conan/conan_toolchain.cmake OPTIONAL)
# include(${CMAKE_BINARY_DIR}/conan/conan_deps.cmake OPTIONAL)

# 设置 C++ 标准
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# 关键：让 CMake 优先查找 Conan 生成的 config 文件
list(PREPEND CMAKE_MODULE_PATH "${CMAKE_BINARY_DIR}")

# 或更明确地指定前缀路径（推荐）
list(PREPEND CMAKE_PREFIX_PATH "${CMAKE_BINARY_DIR}")


# 查找 Conan 安装的 gtest
find_package(GTest REQUIRED)
find_package(fmt REQUIRED)

# 主程序
add_executable(app src/main.cpp)
target_link_libraries(app fmt::fmt)

# 测试程序
enable_testing()
add_executable(unit_tests tests/sample_test.cpp)
target_link_libraries(unit_tests GTest::gtest GTest::gtest_main)
add_test(NAME unit_tests COMMAND unit_tests)