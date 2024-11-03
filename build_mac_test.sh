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

# Clone the repo as "dawn"
git clone https://dawn.googlesource.com/dawn dawn && cd dawn

# Fetch dependencies (lose equivalent of gclient sync)
python tools/fetch_dawn_dependencies.py

mkdir -p out/Debug
cd out/Debug
cmake ../..
make # -j N for N-way parallel build

echo "======================================================================================"
echo "====================================================================================== ls -R lib"
echo "======================================================================================"

ls -R lib

echo "======================================================================================"
echo "====================================================================================== ls -R gen"
echo "======================================================================================"

ls -R gen

echo "======================================================================================"
echo "====================================================================================== gonna zip it up!"
echo "======================================================================================"

# Zip build output

cd ../..

mkdir dawn-$ARCH

cp out/Debug/gen/include/dawn/webgpu.h    dawn-$ARCH
cp out/Debug/webgpu_dawn.so               dawn-$ARCH
cp out/Debug/tint                         dawn-$ARCH
cp src/dawn/native/Release/webgpu_dawn.so dawn-$ARCH

rm -f dawn-mac-$ARCH-$BUILD_DATE.zip
zip -9 -r dawn-mac-$ARCH-$BUILD_DATE.zip dawn-$ARCH || echo "could not zip artifacts"

echo "======================================================================================"
echo "====================================================================================== ls ../.."
echo "======================================================================================"

ls
