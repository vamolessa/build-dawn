# Clone the repo as "dawn"
git clone https://dawn.googlesource.com/dawn dawn && cd dawn

# Fetch dependencies (lose equivalent of gclient sync)
python tools/fetch_dawn_dependencies.py

mkdir -p out/Debug
cd out/Debug
cmake ../..
make # -j N for N-way parallel build

ls -R

# Zip build output
zip -9 -d -r dawn-mac-$ARCH-$BUILD_DATE.zip .
cp dawn-mac-$ARCH-$BUILD_DATE.zip ../..

ls ../..
