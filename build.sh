cd "$(dirname "$0")"

#
# build architecture
#

PROCESSOR_ARCHITECTURE = $(uname -m)
if [ "$PROCESSOR_ARCHITECTURE" = "x86_64" ]; then
  HOST_ARCH="x64"
elif [ "$PROCESSOR_ARCHITECTURE" = "arm64" -o "$PROCESSOR_ARCHITECTURE" = "aarch64" ]; then
  HOST_ARCH="arm64"
fi

if [ "$1" = "x64" ]; then
  TARGET_ARCH=x64
elif [ "$1" = "arm64" ]; then
  TARGET_ARCH=arm64
elif [ -n "$1" ]; then
  echo "Unknown target '$1' architecture"
  exit 1
) else (
  TARGET_ARCH="$HOST_ARCH"
)

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
  git init dawn                                                    || exit 1
  git -C dawn remote add origin https://dawn.googlesource.com/dawn || exit 1
fi

git -C dawn fetch --no-recurse-submodules origin %DAWN_COMMIT% || exit 1
git -C dawn reset --hard FETCH_HEAD                            || exit 1

if [ -e "dawn\third_party\directx-shader-compiler\src" ]; then
  git -C "dawn\third_party\directx-shader-compiler\src" reset --hard HEAD || exit 1
fi

#
# fetch dependencies
#

python "dawn/tools/fetch_dawn_dependencies.py" --directory dawn

#
# patches
#

git apply -p1 --directory=dawn                                         patches/dawn-static-dxc-lib.patch || exit 1
git apply -p1 --directory=dawn/third_party/directx-shader-compiler/src patches/dxc-static-build.patch    || exit 1

#
# configure dawn build
#

cmake.exe                                     \
  -S dawn                                     \
  -B dawn.build-$TARGET_ARCH                  \
  -A $TARGET_ARCH                             \
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
  -D DAWN_ENABLE_METAL=ON                     \
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
  -D TINT_BUILD_MSL_WRITER=ON                 \
  -D TINT_BUILD_CMD_TOOLS=ON                  \
  || exit 1

# TODO: continue here

####################################################################################################

OS=$1
ARCH=$2
OUT_DIR="out/Release"

# Clone the repo as "dawn"
git clone https://dawn.googlesource.com/dawn dawn && cd dawn

# Fetch dependencies (lose equivalent of gclient sync)
python tools/fetch_dawn_dependencies.py

#
# patches
#

mkdir -p $OUT_DIR
cd $OUT_DIR

cmake                                         \
  -S dawn                                    \
  -D CMAKE_BUILD_TYPE=Release                 \
  -D BUILD_SHARED_LIBS=OFF                    \
  -D BUILD_SAMPLES=OFF                        \
  -D DAWN_ENABLE_METAL=ON                     \
  -D DAWN_ENABLE_NULL=OFF                     \
  -D DAWN_ENABLE_DESKTOP_GL=OFF               \
  -D DAWN_ENABLE_OPENGLES=OFF                 \
  -D DAWN_ENABLE_VULKAN=ON                    \
  -D DAWN_USE_GLFW=OFF                        \
  -D DAWN_DXC_ENABLE_ASSERTS_IN_NDEBUG=OFF    \
  -D DAWN_USE_BUILT_DXC=ON                    \
  -D DAWN_ENABLE_SPIRV_VALIDATION=ON          \
  -D DAWN_BUILD_SAMPLES=OFF                   \
  -D TINT_BUILD_TESTS=OFF                     \
  -D TINT_BUILD_SPV_READER=ON                 \
  -D TINT_BUILD_WGSL_WRITER=ON                \
  -D TINT_BUILD_GLSL_WRITER=ON                \
  -D TINT_BUILD_MSL_WRITER=ON                 \
  -D TINT_BUILD_CMD_TOOLS=ON                  \
  || exit 1


if [ "$HOST_ARCH" != "$TARGET_ARCH" ]; then
  
fi

#make # -j N for N-way parallel build
cmake --build . --config Release --target webgpu_dawn tint_cmd_tint_cmd || exit 1

# Zip build output

cd ../..

mkdir dawn-$OS-$ARCH

echo $DAWN_COMMIT > dawn-$OS-$ARCH/commit.txt

cp $OUT_DIR/gen/include/dawn/webgpu.h             dawn-$OS-$ARCH
cp $OUT_DIR/tint                                  dawn-$OS-$ARCH
cp $OUT_DIR/src/dawn/native/libwebgpu_dawn.dylib  dawn-$OS-$ARCH
cp $OUT_DIR/src/tint/libtint_api.a                dawn-$OS-$ARCH

rm -f dawn-$OS-$ARCH-$BUILD_DATE.zip
zip -9 -r dawn-$OS-$ARCH-$BUILD_DATE.zip dawn-$OS-$ARCH || echo "could not zip artifacts"
cp -f dawn-$OS-$ARCH-$BUILD_DATE.zip .. || echo "could not copy zip artifacts to root dir"
