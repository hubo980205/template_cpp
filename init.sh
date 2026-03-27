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
    # 确保 profiles 目录存在，否则创建一个空的以便列出
    mkdir -p "$PROFILES_DIR"
    
    if compgen -G "$PROFILES_DIR/*" > /dev/null 2>&1; then
        echo "可用的 Conan profiles:"
        for profile in "$PROFILES_DIR"/*; do
            if [[ -f "$profile" ]]; then
                basename "$profile"
            fi
        done | sort
    else
        echo "Conan profiles 目录为空: $PROFILES_DIR"
        echo "请先运行 'conan profile detect' 或将 profile 文件放入项目 cmake/conan/profiles/ 目录后使用 -p 选项。"
    fi
}

# === 第一步：解析命令行参数 ===
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

# === 第二步：如果请求列出 profiles，则立即执行并退出 ===
if [[ "$SHOW_LIST" == true ]]; then
    list_profiles
    exit 0
fi

# === 第三步：处理 profile 同步逻辑（现在 PROFILE 已知）===
PROJECT_PROFILES="$PROJECT_ROOT/cmake/conan/profiles"
if [[ -n "$PROFILE" ]]; then
    # 如果项目内存在同名 profile，则同步到 Conan 目录
    if [[ -f "$PROJECT_PROFILES/$PROFILE" ]]; then
        mkdir -p "$PROFILES_DIR"
        echo "使用项目内 profile: $PROJECT_PROFILES/$PROFILE"
        cp "$PROJECT_PROFILES/$PROFILE" "$PROFILES_DIR/"
    fi

    # 如果 Conan 目录里还是没有这个 profile，报错
    if [[ ! -f "$PROFILES_DIR/$PROFILE" ]]; then
        echo "错误: Profile '$PROFILE' 不存在。"
        echo "  1. 请确保它存在于 Conan 目录: $PROFILES_DIR"
        echo "  2. 或者将其放入项目目录: $PROJECT_PROFILES"
        echo ""
        list_profiles
        exit 1
    fi
else
    # 如果用户既没指定 -p 也没指定 -l，则提示用法
    echo "未指定 profile (-p)"
    echo ""
    list_profiles
    echo ""
    echo "请使用 -p <profile> 指定一个配置"
    exit 1
fi

# === 第四步：确定构建目录 ===
if [[ -z "$BUILD_DIR" ]]; then
    BUILD_DIR="build-${PROFILE}"
fi
BUILD_PATH="$PROJECT_ROOT/$BUILD_DIR"

echo "正在初始化构建环境..."
echo "   Profile:      $PROFILE"
echo "   Build dir:    $BUILD_PATH"
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
    # 交叉编译或其他自定义 profile：默认设为 Release
    CMAKE_BUILD_TYPE="Release"
fi

cmake "$PROJECT_ROOT" \
    -DCMAKE_TOOLCHAIN_FILE=conan_toolchain.cmake \
    -DCMAKE_BUILD_TYPE="$CMAKE_BUILD_TYPE"

echo ""
echo "初始化完成！"
echo "构建命令: cd $BUILD_DIR && cmake --build ."