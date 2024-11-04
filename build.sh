cd "$(dirname "$0")"

OS=$1
ARCH=$2

# Clone the repo as "dawn"
git clone https://dawn.googlesource.com/dawn dawn && cd dawn

# Fetch dependencies (lose equivalent of gclient sync)
python tools/fetch_dawn_dependencies.py

mkdir -p out/Debug
cd out/Debug
cmake ../..
make # -j N for N-way parallel build

# Zip build output

cd ../..

mkdir dawn-$OS-$ARCH

cp out/Debug/gen/include/dawn/webgpu.h             dawn-$OS-$ARCH
cp out/Debug/tint                                  dawn-$OS-$ARCH
cp out/Debug/src/dawn/native/libdawn_native.a      dawn-$OS-$ARCH
cp out/Debug/Makefile                              dawn-$OS-$ARCH
#cp out/Debug/src/dawn/native/libdawn_native.dylib  dawn-$ARCH

rm -f dawn-$OS-$ARCH-$BUILD_DATE.zip
zip -9 -r dawn-$OS-$ARCH-$BUILD_DATE.zip dawn-$OS-$ARCH || echo "could not zip artifacts"
cp -f dawn-$OS-$ARCH-$BUILD_DATE.zip .. || echo "could not copy zip artifacts to root dir"
