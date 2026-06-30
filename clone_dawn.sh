#!/bin/sh

cd "$(dirname "$0")"

die() {
  echo "ERROR: $1"
  exit 1
}

command -v git || die "'git' not found"

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

#command -v python && python "dawn/tools/fetch_dawn_dependencies.py" --directory dawn

git apply -p1 --directory=dawn                                         patches/dawn-static-dxc-lib.patch || die "could not apply dawn-static-dxc-lib patch"
git apply -p1 --directory=dawn/third_party/directx-shader-compiler/src patches/dxc-static-build.patch    || die "could not apply dxc-static-build patch"

echo "DAWN CLONED!"

ls
