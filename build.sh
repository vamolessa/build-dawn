cd "$(dirname "$0")"

OS=$1
ARCH=$2
OUT_DIR="out/Release"

# Clone the repo as "dawn"
git clone https://dawn.googlesource.com/dawn dawn && cd dawn

# Fetch dependencies (lose equivalent of gclient sync)
python tools/fetch_dawn_dependencies.py

mkdir -p $OUT_DIR
cd $OUT_DIR

cmake                                         \
  -S ../..                                    \
  -D CMAKE_BUILD_TYPE=Release                 \
  -D BUILD_SHARED_LIBS=OFF                    \
  -D BUILD_SAMPLES=OFF                        \
  -D DAWN_ENABLE_METAL=ON                     \
  -D DAWN_ENABLE_NULL=OFF                     \
  -D DAWN_ENABLE_DESKTOP_GL=OFF               \
  -D DAWN_ENABLE_OPENGLES=OFF                 \
  -D DAWN_ENABLE_VULKAN=ON                    \
  -D DAWN_USE_GLFW=OFF                        \
  -D DAWN_ENABLE_SPIRV_VALIDATION=ON          \
  -D DAWN_BUILD_SAMPLES=OFF                   \
  -D TINT_ENABLE_INSTALL=ON                   \
  -D TINT_BUILD_SPV_READER=ON                 \
  -D TINT_BUILD_WGSL_WRITER=ON                \
  -D TINT_BUILD_TESTS=OFF                     \
  || exit 1

#make # -j N for N-way parallel build
cmake.exe --build dawn.build-%ARCH% --config Release --target webgpu_dawn tint_cmd_tint_cmd || exit /b 1

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
