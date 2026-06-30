@echo off
setlocal enabledelayedexpansion

cd %~dp0

where /q git.exe    || echo ERROR: "git.exe" not found    && exit /b 1
rem where /q python.exe || echo ERROR: "python.exe" not found && exit /b 1

if "%DAWN_COMMIT%" equ "" (
  for /f "tokens=1 usebackq" %%F IN (`git ls-remote https://dawn.googlesource.com/dawn HEAD`) do set DAWN_COMMIT=%%F
)

if not exist dawn (
  call git init dawn                                                    || exit /b 1
  call git -C dawn remote add origin https://dawn.googlesource.com/dawn || exit /b 1
)

rem call git -C dawn fetch --no-recurse-submodules origin %DAWN_COMMIT% || exit /b 1
call git -C dawn fetch origin %DAWN_COMMIT%                         || exit /b 1
call git -C dawn reset --hard FETCH_HEAD                            || exit /b 1

rem if exist dawn\third_party\directx-shader-compiler\src call git -C dawn\third_party\directx-shader-compiler\src reset --hard HEAD || exit /b 1

rem call python "dawn/tools/fetch_dawn_dependencies.py" --directory dawn

rem call git apply -p1 --directory=dawn                                         patches/dawn-static-dxc-lib.patch || exit /b 1
rem call git apply -p1 --directory=dawn/third_party/directx-shader-compiler/src patches/dxc-static-build.patch    || exit /b 1

echo DAWN CLONED!

dir
