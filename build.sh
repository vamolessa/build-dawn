#!/bin/sh

cd "$(dirname "$0")"

#
# build architecture
#

PROCESSOR_ARCHITECTURE=$(uname -m)
if [ "$PROCESSOR_ARCHITECTURE" = "x86_64" ]; then
  HOST_ARCH="x64"
elif [ "$PROCESSOR_ARCHITECTURE" = "arm64" ] || [ "$PROCESSOR_ARCHITECTURE" = "aarch64" ]; then
  HOST_ARCH="arm64"
fi

OS="$1"

if [ "$2" = "x64" ]; then
  TARGET_ARCH=x64
elif [ "$2" = "arm64" ]; then
  TARGET_ARCH=arm64
elif [ -n "$2" ]; then
  echo "Unknown target '$2' architecture"
  exit 1
else
  TARGET_ARCH="$HOST_ARCH"
fi

#
# dependencies
#

which git    2> /dev/null || echo "ERROR: 'git' not found"    && exit 1
which cmake  2> /dev/null || echo "ERROR: 'cmake' not found"  && exit 1
which python 2> /dev/null || echo "ERROR: 'python' not found" && exit 1

#
# clone dawn
#

if [ -z "$DAWN_COMMIT" ]; then
  DAWN_COMMIT=$(git ls-remote https://dawn.googlesource.com/dawn HEAD | awk '{print $1}')
fi

if [ ! -e "dawn" ]; then
  git init dawn                                                    || echo "ERROR: could not init dawn git repo" && exit 1
  git -C dawn remote add origin https://dawn.googlesource.com/dawn || echo "ERROR: could not init dawn git repo" && exit 1
fi

git -C dawn fetch --no-recurse-submodules origin %DAWN_COMMIT% || echo "ERROR: could not fetch from dawn git repo" && exit 1
git -C dawn reset --hard FETCH_HEAD                            || echo "ERROR: could not fetch from dawn git repo" && exit 1

if [ -e "dawn/third_party/directx-shader-compiler/src" ]; then
  git -C "dawn/third_party/directx-shader-compiler/src" reset --hard HEAD || echo "ERROR: could not reset dxc git" && exit 1
fi

#
# fetch dependencies
#

python "dawn/tools/fetch_dawn_dependencies.py" --directory dawn

#
# patches
#

git apply -p1 --directory=dawn                                         patches/dawn-static-dxc-lib.patch || echo "ERROR: could not apply dawn-static-dxc-lib patch" && exit 1
git apply -p1 --directory=dawn/third_party/directx-shader-compiler/src patches/dxc-static-build.patch    || echo "ERROR: could not apply dxc-static-build patch" && exit 1

#
# configure dawn build
#

if [ "$OS" = "mac" ]; then
  METAL_SWITCH=ON
else
  METAL_SWITCH=OFF
fi

cmake                                         \
  -S dawn                                     \
  -B "dawn.build-$TARGET_ARCH"                \
  -A "$TARGET_ARCH"                           \
  -D CMAKE_BUILD_TYPE=Release                 \
  -D CMAKE_POLICY_DEFAULT_CMP0091=NEW         \
  -D CMAKE_POLICY_DEFAULT_CMP0092=NEW         \
  -D CMAKE_MSVC_RUNTIME_LIBRARY=MultiThreaded \
  -D ABSL_MSVC_STATIC_RUNTIME=ON              \
  -D DAWN_BUILD_SAMPLES=OFF                   \
  -D DAWN_BUILD_TESTS=OFF                     \
  -D DAWN_ENABLE_D3D12=OFF                    \
  -D DAWN_ENABLE_D3D11=OFF                    \
  -D DAWN_ENABLE_NULL=OFF                     \
  -D DAWN_ENABLE_DESKTOP_GL=OFF               \
  -D DAWN_ENABLE_OPENGLES=OFF                 \
  -D DAWN_ENABLE_VULKAN=ON                    \
  -D DAWN_ENABLE_METAL=$METAL_SWITCH          \
  -D DAWN_USE_GLFW=OFF                        \
  -D DAWN_ENABLE_SPIRV_VALIDATION=OFF         \
  -D DAWN_DXC_ENABLE_ASSERTS_IN_NDEBUG=OFF    \
  -D DAWN_USE_BUILT_DXC=ON                    \
  -D DAWN_FETCH_DEPENDENCIES=OFF              \
  -D DAWN_BUILD_MONOLITHIC_LIBRARY=SHARED     \
  -D TINT_BUILD_TESTS=OFF                     \
  -D TINT_BUILD_SPV_READER=ON                 \
  -D TINT_BUILD_SPV_WRITER=ON                 \
  -D TINT_BUILD_WGSL_WRITER=ON                \
  -D TINT_BUILD_GLSL_WRITER=ON                \
  -D TINT_BUILD_MSL_WRITER=$METAL_SWITCH      \
  -D TINT_BUILD_CMD_TOOLS=ON                  \
  || echo "ERROR: could not cmake configure dawn" && exit 1

if [ "$HOST_ARCH" != "$TARGET_ARCH" ]; then

  #
  # build native architecture tblgen executables for dxc
  #

  cmake                                             \
    -S dawn/third_party/directx-shader-compiler/src \
    -B "dawn.build-$TARGET_ARCH/dxc-native"         \
    -A "$HOST_ARCH"                                 \
    -D CMAKE_BUILD_TYPE=Release                     \
    -D BUILD_SHARED_LIBS=OFF                        \
    -D LLVM_TARGETS_TO_BUILD=None                   \
    -D LLVM_ENABLE_WARNINGS=OFF                     \
    -D LLVM_ENABLE_EH=ON                            \
    -D LLVM_ENABLE_RTTI=ON                          \
    || echo "ERROR: could not cmake build dxc" && exit 1

  # first build target architecture tblgen exe's
  cmake --build "dawn.build-$TARGET_ARCH" --config Release --target llvm-tblgen clang-tblgen || echo "ERROR: could not cmake build tblgen" && exit 1

  # then build host architecture tblgen's
  cmake --build "dawn.build-$TARGET_ARCH/dxc-native" --config Release --target llvm-tblgen clang-tblgen || echo "ERROR: could not cmake build host arch tblgen" && exit 1

  # move host arch exe's (newer timestamp) over target arch exe's (older timestamp)
  # so next dawn build steps will be able to use these exe's for different target arch
  mv -f "dawn.build-$TARGET_ARCH/dxc-native/Release/bin/llvm-tblgen"  "dawn.build-$TARGET_ARCH/third_party/directx-shader-compiler/src/Release/bin/llvm-tblgen"
  mv -f "dawn.build-$TARGET_ARCH/dxc-native/Release/bin/clang-tblgen" "dawn.build-$TARGET_ARCH/third_party/directx-shader-compiler/src/Release/bin/clang-tblgen"

fi

#
# run the full dawn build
#

#CL=/Zi /Wv:18
#LINK=/OPT:REF /OPT:ICF /DEBUG /PDBALTPATH:%%_PDB%% /PDBSTRIPPED
cmake --build "dawn.build-$TARGET_ARCH" --config Release --target webgpu_dawn tint_cmd_tint_cmd --parallel || echo "ERROR: could not cmake build dawn" && exit 1

#
# prepare output folder
#

rm -rf "dawn-$TARGET_ARCH"
mkdir "dawn-$TARGET_ARCH"

echo "$DAWN_COMMIT" > "dawn-$TARGET_ARCH/commit.txt"

cp -f "dawn.build-$TARGET_ARCH/gen/include/dawn/webgpu.h"    "dawn-$TARGET_ARCH" || echo "ERROR: could not copy webgpu.h"       && exit 1
cp -f "dawn.build-$TARGET_ARCH/Release/libwebgpu_dawn.dylib" "dawn-$TARGET_ARCH" || echo "ERROR: could not copy libwebgpu_dawn" && exit 1
cp -f "dawn.build-$TARGET_ARCH/Release/tint"                 "dawn-$TARGET_ARCH" || echo "ERROR: could not copy tint"           && exit 1

#
# Done!
#

if [ -n "$GITHUB_WORKFLOW" ]; then

  #
  # GitHub actions stuff
  #

  tar -cavf "dawn-$OS-$TARGET_ARCH-$BUILD_DATE.zip" "dawn-$TARGET_ARCH" || echo "ERROR: could not create final tar" && exit 1
fi
