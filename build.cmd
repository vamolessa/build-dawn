@echo off
setlocal enabledelayedexpansion

cd %~dp0

rem
rem build architecture
rem

if "%1" equ "x64" (
  set ARCH=x64
) else if "%1" equ "arm64" (
  set ARCH=arm64
) else if "%1" neq "" (
  echo Unknown target "%1" architecture!
  exit /b 1
) else if "%PROCESSOR_ARCHITECTURE%" equ "AMD64" (
  set ARCH=x64
) else if "%PROCESSOR_ARCHITECTURE%" equ "ARM64" (
  set ARCH=arm64
)

rem
rem dependencies
rem

where /q git.exe || (
  echo ERROR: "git.exe" not found
  exit /b 1
)

where /q cmake.exe || (
  echo ERROR: "cmake.exe" not found
  exit /b 1
)

rem
rem 7-Zip
rem

if exist "%ProgramFiles%\7-Zip\7z.exe" (
  set SZIP="%ProgramFiles%\7-Zip\7z.exe"
) else (
  where /q 7za.exe || (
    echo ERROR: 7-Zip installation or "7za.exe" not found
    exit /b 1
  )
  set SZIP=7za.exe
)

rem
rem get depot tools
rem

set PATH=%CD%\depot_tools;%PATH%
set DEPOT_TOOLS_WIN_TOOLCHAIN=0

if not exist depot_tools (
  call git clone --depth=1 --no-tags --single-branch https://chromium.googlesource.com/chromium/tools/depot_tools.git || exit /b 1
)

rem
rem clone dawn
rem

if "%DAWN_COMMIT%" equ "" (
  for /f "tokens=1 usebackq" %%F IN (`git ls-remote https://dawn.googlesource.com/dawn HEAD`) do set DAWN_COMMIT=%%F
)

if not exist dawn (
  mkdir dawn
  pushd dawn
  call git init .                                               || exit /b 1
  call git remote add origin https://dawn.googlesource.com/dawn || exit /b 1
  popd
)

pushd dawn

call git fetch origin %DAWN_COMMIT%  || exit /b 1
call git checkout --force FETCH_HEAD || exit /b 1

copy /y scripts\standalone.gclient .gclient
"C:\Program Files\Git\usr\bin\sed.exe" -i.bak -e "/'third_party\/catapult'\: /,+3d" -e "/'third_party\/swiftshader'\: /,+3d" -e "/'third_party\/angle'\: /,+3d" -e "/'third_party\/webgpu-cts'\: /,+3d" -e "/'third_party\/vulkan-validation-layers\/src'\: /,+3d" -e "/'third_party\/khronos\/OpenGL-Registry'\: /,+3d" DEPS || exit /b 1
call gclient sync -f -D -R || exit /b 1

popd

rem
rem build dawn
rem

cmake                                         ^
  -S dawn                                     ^
  -B dawn.build-%ARCH%                        ^
  -A %ARCH%,version=10.0.26100.0              ^
  -D CMAKE_BUILD_TYPE=Release                 ^
  -D CMAKE_POLICY_DEFAULT_CMP0091=NEW         ^
  -D CMAKE_POLICY_DEFAULT_CMP0092=NEW         ^
  -D CMAKE_MSVC_RUNTIME_LIBRARY=MultiThreaded ^
  -D BUILD_SHARED_LIBS=OFF                    ^
  -D BUILD_SAMPLES=OFF                        ^
  -D DAWN_ENABLE_D3D12=ON                     ^
  -D DAWN_ENABLE_D3D11=ON                     ^
  -D DAWN_ENABLE_NULL=OFF                     ^
  -D DAWN_ENABLE_DESKTOP_GL=OFF               ^
  -D DAWN_ENABLE_OPENGLES=OFF                 ^
  -D DAWN_ENABLE_VULKAN=ON                    ^
  -D DAWN_USE_GLFW=OFF                        ^
  -D DAWN_BUILD_SAMPLES=OFF                   ^
  -D TINT_ENABLE_INSTALL=ON                   ^
  -D TINT_BUILD_SPV_READER=ON                 ^
  -D TINT_BUILD_WGSL_WRITER=ON                ^
  -D TINT_BUILD_TESTS=OFF                     ^
  || exit /b 1

set CL=/Wv:18
cmake.exe --build dawn.build-%ARCH% --config Release --target webgpu_dawn tint_cmd_tint_cmd --parallel || exit /b 1

rem
rem prepare output folder
rem

mkdir dawn-%ARCH%

echo %DAWN_COMMIT% > dawn-%ARCH%\commit.txt

copy /y dawn.build-%ARCH%\gen\include\dawn\webgpu.h               dawn-%ARCH%
copy /y dawn.build-%ARCH%\Release\webgpu_dawn.dll                 dawn-%ARCH%
copy /y dawn.build-%ARCH%\Release\tint.exe                        dawn-%ARCH%
copy /y dawn.build-%ARCH%\src\dawn\native\Release\webgpu_dawn.lib dawn-%ARCH%

rem
rem Done!
rem

if "%GITHUB_WORKFLOW%" neq "" (

  rem
  rem GitHub actions stuff
  rem

  %SZIP% a -y -mx=9 dawn-win-%ARCH%-%BUILD_DATE%.zip dawn-%ARCH% || exit /b 1
)
