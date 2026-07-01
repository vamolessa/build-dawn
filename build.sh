#!/bin/sh

cd "$(dirname "$0")"

die() {
  echo "ERROR: $1"
  exit 1
}

#
# build architecture
#

echo "build architecture"

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
  die "Unknown target '$2' architecture"
else
  TARGET_ARCH="$HOST_ARCH"
fi

#
# dependencies
#

echo "dependencies"

command -v git     || die "'git' not found"
command -v cmake   || die "'cmake' not found"
command -v clang   || die "'clang' not found"
command -v clang++ || die "'clang++' not found"
command -v python  || die "'python' not found"

#
# clone dawn
#

echo "clone dawn"

if [ -z "$DAWN_COMMIT" ]; then
  DAWN_COMMIT=$(git ls-remote https://dawn.googlesource.com/dawn HEAD | awk '{print $1}')
fi

if [ ! -e "dawn" ]; then
  git init dawn                                                    || die "could not init dawn git repo"
  git -C dawn remote add origin https://dawn.googlesource.com/dawn || die "could not init dawn git repo"
fi

git -C dawn fetch --no-recurse-submodules origin "$DAWN_COMMIT" || die "could not fetch from dawn git repo"
git -C dawn reset --hard FETCH_HEAD                             || die "could not fetch from dawn git repo"

if [ -e "dawn/third_party/directx-shader-compiler/src" ]; then
  git -C "dawn/third_party/directx-shader-compiler/src" reset --hard HEAD || die "could not reset dxc git"
fi

#
# fetch dependencies
#

echo "fetch dependencies"

python "dawn/tools/fetch_dawn_dependencies.py" --directory dawn

#
# patches
#

#echo "patches"

#git apply -p1 --directory=dawn                                         patches/dawn-static-dxc-lib.patch || die "could not apply dawn-static-dxc-lib patch"
#git apply -p1 --directory=dawn/third_party/directx-shader-compiler/src patches/dxc-static-build.patch    || die "could not apply dxc-static-build patch"

#
# configure dawn build
#

echo "configure dawn build"

if [ "$OS" = "mac" ]; then
  MAC_SWITCH=ON
  CMAKE_FLAGS="-GNinja"
else
  MAC_SWITCH=OFF
  CMAKE_FLAGS=""
fi

  # taken out from right before the first `-D` since makefile target does not support it
  #-A "$TARGET_ARCH"                          \

cmake                                         \
  -S dawn                                     \
  -B "dawn.build-$TARGET_ARCH"                \
  $CMAKE_FLAGS                                \
  -D CMAKE_C_COMPILER=clang                   \
  -D CMAKE_CXX_COMPILER=clang++               \
  -D CMAKE_BUILD_TYPE=Release                 \
  -D DAWN_TARGET_MACOS=$MAC_SWITCH            \
  -D DAWN_BUILD_SAMPLES=OFF                   \
  -D DAWN_BUILD_TESTS=OFF                     \
  -D DAWN_ENABLE_D3D12=OFF                    \
  -D DAWN_ENABLE_D3D11=OFF                    \
  -D DAWN_ENABLE_NULL=OFF                     \
  -D DAWN_ENABLE_DESKTOP_GL=OFF               \
  -D DAWN_ENABLE_OPENGLES=OFF                 \
  -D DAWN_ENABLE_VULKAN=ON                    \
  -D DAWN_ENABLE_METAL=$MAC_SWITCH            \
  -D DAWN_USE_GLFW=OFF                        \
  -D DAWN_USE_X11=OFF                         \
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
  -D TINT_BUILD_MSL_WRITER=ON                 \
  -D TINT_BUILD_CMD_TOOLS=ON                  \
  || die "could not cmake configure dawn"

if [ "$HOST_ARCH" != "$TARGET_ARCH" ]; then

  #
  # build native architecture tblgen executables for dxc
  #

  echo "build native architecture tblgen executables for dxc"

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
    || die "could not cmake build dxc"

  # first build target architecture tblgen exe's
  cmake --build "dawn.build-$TARGET_ARCH" --config Release --target llvm-tblgen clang-tblgen || die "could not cmake build tblgen"

  # then build host architecture tblgen's
  cmake --build "dawn.build-$TARGET_ARCH/dxc-native" --config Release --target llvm-tblgen clang-tblgen || die "could not cmake build host arch tblgen"

  # move host arch exe's (newer timestamp) over target arch exe's (older timestamp)
  # so next dawn build steps will be able to use these exe's for different target arch
  mv -f "dawn.build-$TARGET_ARCH/dxc-native/Release/bin/llvm-tblgen"  "dawn.build-$TARGET_ARCH/third_party/directx-shader-compiler/src/Release/bin/llvm-tblgen"
  mv -f "dawn.build-$TARGET_ARCH/dxc-native/Release/bin/clang-tblgen" "dawn.build-$TARGET_ARCH/third_party/directx-shader-compiler/src/Release/bin/clang-tblgen"

fi

#
# run the full dawn build
#

echo "run the full dawn build"

#CL=/Zi /Wv:18
#LINK=/OPT:REF /OPT:ICF /DEBUG /PDBALTPATH:%%_PDB%% /PDBSTRIPPED
cmake --build "dawn.build-$TARGET_ARCH" --config Release --target webgpu_dawn tint_cmd_tint_cmd --parallel || die "could not cmake build dawn"

#
# prepare output folder
#

echo "prepare output folder"

rm -rf "dawn-$TARGET_ARCH"
mkdir "dawn-$TARGET_ARCH"

echo "$DAWN_COMMIT" > "dawn-$TARGET_ARCH/commit.txt"

cp -f "dawn.build-$TARGET_ARCH/gen/include/dawn/webgpu.h"    "dawn-$TARGET_ARCH" || die "could not copy webgpu.h"
cp -f "dawn.build-$TARGET_ARCH/Release/libwebgpu_dawn.dylib" "dawn-$TARGET_ARCH" || die "could not copy libwebgpu_dawn"
cp -f "dawn.build-$TARGET_ARCH/Release/tint"                 "dawn-$TARGET_ARCH" || die "could not copy tint"

#
# Done!
#

echo "Done!"

if [ -n "$GITHUB_WORKFLOW" ]; then

  #
  # GitHub actions stuff
  #

  echo "GitHub actions stuff"

  tar -cavf "dawn-$OS-$TARGET_ARCH-$BUILD_DATE.zip" "dawn-$TARGET_ARCH" || die "could not create final tar"
fi
