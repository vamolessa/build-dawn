cd "$(dirname "$0")"

#
# build architecture
#

if [ "$1" == "x64" ]; then
  ARCH=x64
elif [ "$1" == "arm64" ]; then
  ARCH=arm64
elif [ -z "$1"]; then
  echo "Unknown target '$1' architecture!"
  exit 1
elif [ "$PROCESSOR_ARCHITECTURE" == "AMD64" ]; then
  ARCH=x64
elif [ "$PROCESSOR_ARCHITECTURE" == "ARM64" ]; then
  ARCH=arm64
else
  echo "Unknown target architecture!"
  exit 1
fi

#
# dependencies
#

which git > /dev/null || (
  echo "ERROR: git not found"
  exit 1
)

which cmake > /dev/null || (
  echo "ERROR: cmake not found"
  exit 1
)

#
# get depot tools
#

export PATH=$PWD/depot_tools:$PATH
export DEPOT_TOOLS_MAC_TOOLCHAIN=0

if [ ! -d depot_tools ]; then
  git clone --depth=1 --no-tags --single-branch https://chromium.googlesource.com/chromium/tools/depot_tools.git || exit 1
fi

#
# clone dawn
#

if [ "$DAWN_COMMIT" == "" ]; then
  DAWN_COMMIT=$(git ls-remote https://dawn.googlesource.com/dawn HEAD | cut -w -f 1)
fi

if [ ! -d dawn ]; then
  mkdir dawn
  pushd dawn
  git init . || exit 1
  git remote add origin https://dawn.googlesource.com/dawn || exit 1
  popd
fi

pushd dawn

git fetch origin $DAWN_COMMIT || exit 1
git checkout --force FETCH_HEAD || exit 1

cp -f scripts/standalone.gclient .gclient
sed -i.bak -e "/'third_party\/catapult'\: /,+3d" -e "/'third_party\/swiftshader'\: /,+3d" -e "/'third_party\/angle'\: /,+3d" -e "/'third_party\/webgpu-cts'\: /,+3d" -e "/'third_party\/vulkan-validation-layers\/src'\: /,+3d" -e "/'third_party\/khronos\/OpenGL-Registry'\: /,+3d" DEPS || exit 1
gclient sync -f -D -R || exit 1

echo "DEPS file:"
cat DEPS

popd

#
# build dawn
#

#  -A $ARCH                                    \
cmake                                         \
  -S dawn                                     \
  -B dawn.build-$ARCH                         \
  -D CMAKE_BUILD_TYPE=Release                 \
  -D CMAKE_POLICY_DEFAULT_CMP0091=NEW         \
  -D CMAKE_POLICY_DEFAULT_CMP0092=NEW         \
  -D CMAKE_MSVC_RUNTIME_LIBRARY=MultiThreaded \
  -D BUILD_SHARED_LIBS=OFF                    \
  -D BUILD_SAMPLES=OFF                        \
  -D DAWN_ENABLE_METAL=ON                     \
  -D DAWN_ENABLE_NULL=OFF                     \
  -D DAWN_ENABLE_DESKTOP_GL=OFF               \
  -D DAWN_ENABLE_OPENGLES=OFF                 \
  -D DAWN_ENABLE_VULKAN=ON                    \
  -D DAWN_USE_GLFW=OFF                        \
  -D DAWN_BUILD_SAMPLES=OFF                   \
  -D TINT_ENABLE_INSTALL=ON                   \
  -D TINT_BUILD_SPV_READER=ON                 \
  -D TINT_BUILD_WGSL_WRITER=ON                \
  -D TINT_BUILD_TESTS=OFF                     \
  || exit 1

cmake --build dawn.build-$ARCH --config Release --target webgpu_dawn tint_cmd_tint_cmd --parallel || exit 1

#
# prepare output folder
#

mkdir dawn-$ARCH

echo $DAWN_COMMIT > dawn-$ARCH/commit.txt

cp -f dawn.build-$ARCH/gen/include/dawn/webgpu.h              dawn-$ARCH
cp -f dawn.build-$ARCH/Release/webgpu_dawn.so                 dawn-$ARCH
cp -f dawn.build-$ARCH/Release/tint                           dawn-$ARCH
cp -f dawn.build-$ARCH/src/dawn/native/Release/webgpu_dawn.so dawn-$ARCH

#
# Done!
#

if [ ! -z "$GITHUB_WORKFLOW" ]; then

  #
  # GitHub actions stuff
  #

  #$SZIP a -y -mx=9 dawn-win-%ARCH%-%BUILD_DATE%.zip dawn-$ARCH || exit 1
  zip -9 -d -r dawn-win-%ARCH%-%BUILD_DATE%.zip dawn-$ARCH || exit 1
fi

###

echo "ARCH = $ARCH !!"
echo "placeholder" > dawn-mac-${ARCH}-${BUILD_DATE}.zip
