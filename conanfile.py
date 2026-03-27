from conan import ConanFile
from conan.tools.cmake import CMake, CMakeToolchain

class HelloConan(ConanFile):
    settings = "os", "compiler", "build_type", "arch"
    generators = "CMakeDeps"
    exports_sources = "CMakeLists.txt", "src/*", "tests/*", "include/*", "cmake/*" ,".github/workflows/*"
    # we can find other packages in url "https://conan.org.cn/center?"
    def requirements(self):
        self.requires("fmt/12.1.0")
        self.requires("gtest/1.17.0")
        # 添加需要的包
    def tool_requirements(self):
        self.tool_requires("cmake/3.31.11")

    def generate(self):
        # 生成 toolchain 文件（包含交叉编译器路径、arch 等）
        tc = CMakeToolchain(self)
        tc.generate()

    def build(self):
        cmake = CMake(self)
        cmake.configure()  # 调用 cmake + toolchain
        cmake.build()      # 执行编译

# conan install .. --profile:host=debug --output-folder=build-conan --build=missing
# conan build .. --profile:host=debug --output-folder=build-conan