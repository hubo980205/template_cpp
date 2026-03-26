#!/bin/bash
# init.sh - 智能初始化 Conan + CMake 构建环境
# 支持自动发现 Conan profiles，并一键配置多平台构建

set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONAN_HOME=$(conan config home 2>/dev/null || echo "$HOME/.conan2")
PROFILES_DIR="$CONAN_HOME/profiles"

usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -p PROFILE    使用指定的 Conan profile 初始化构建环境"
    echo "  -l            列出所有可用的 Conan profiles"
    echo "  -b DIR        指定构建目录名（默认：build-<profile>）"
    echo "  -h            显示此帮助"
    echo ""
    echo "Examples:"
    echo "  $0 -l"
    echo "  $0 -p release"
    echo "  $0 -p arm-linux -b my_arm_build"
    exit 1
}

list_profiles() {
    if [[ ! -d "$PROFILES_DIR" ]]; then
        echo "Conan profiles 目录不存在: $PROFILES_DIR"
        echo "请先运行 'conan profile detect' 或手动创建 profiles"
        exit 1
    fi

    echo "可用的 Conan profiles:"
    for profile in "$PROFILES_DIR"/*; do
        if [[ -f "$profile" ]]; then
            basename "$profile"
        fi
    done | sort
}

# 解析参数
PROFILE=""
BUILD_DIR=""
SHOW_LIST=false

while getopts "p:b:lh" opt; do
    case $opt in
        p) PROFILE="$OPTARG" ;;
        b) BUILD_DIR="$OPTARG" ;;
        l) SHOW_LIST=true ;;
        h) usage ;;
        *) usage ;;
    esac
done

# 如果请求列出 profiles
if [[ "$SHOW_LIST" == true ]]; then
    list_profiles
    exit 0
fi

# 如果未指定 profile，提示并列出
if [[ -z "$PROFILE" ]]; then
    echo "未指定 profile (-p)"
    echo ""
    list_profiles
    echo ""
    echo "请使用 -p <profile> 指定一个配置"
    exit 1
fi

# 检查 profile 是否存在
if [[ ! -f "$PROFILES_DIR/$PROFILE" ]]; then
    echo "Profile '$PROFILE' 不存在于 $PROFILES_DIR"
    echo ""
    list_profiles
    exit 1
fi

# 自动生成构建目录名（如果未指定）
if [[ -z "$BUILD_DIR" ]]; then
    BUILD_DIR="build-${PROFILE}"
fi

BUILD_PATH="$PROJECT_ROOT/$BUILD_DIR"

echo "正在初始化构建环境..."
echo "   Profile:    $PROFILE"
echo "   Build dir:  $BUILD_PATH"
echo "   Profiles dir: $PROFILES_DIR"
echo ""

# 创建并进入构建目录
mkdir -p "$BUILD_PATH"
cd "$BUILD_PATH"

# Step 1: 安装依赖
echo "运行 conan install ..."
conan install "$PROJECT_ROOT" \
    --output-folder=. \
    --profile:host="$PROFILE" \
    --profile:build=default \
    --build=missing

# Step 2: 配置 CMake
echo "运行 cmake 配置 ..."

# 判断是否为本地构建（用于设置 CMAKE_BUILD_TYPE）
if [[ "$PROFILE" == "debug" ]]; then
    CMAKE_BUILD_TYPE="Debug"
elif [[ "$PROFILE" == "release" ]]; then
    CMAKE_BUILD_TYPE="Release"
else
    # 交叉编译或其他自定义 profile：默认设为 Release（可按需调整）
    CMAKE_BUILD_TYPE="Release"
fi

cmake "$PROJECT_ROOT" \
    -DCMAKE_TOOLCHAIN_FILE=conan_toolchain.cmake \
    -DCMAKE_BUILD_TYPE="$CMAKE_BUILD_TYPE"

echo ""
echo "初始化完成！"
echo "构建命令: cd $BUILD_DIR && cmake --build ."