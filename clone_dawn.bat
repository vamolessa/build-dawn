@echo off
setlocal enabledelayedexpansion

cd %~dp0

rem set REPO_URL=https://dawn.googlesource.com/dawn
set REPO_URL=https://github.com/google/dawn

if "%DAWN_COMMIT%" equ "" (
  for /f "tokens=1 usebackq" %%F IN (`git ls-remote %REPO_URL% HEAD`) do set DAWN_COMMIT=%%F
)

if not exist dawn (
  call git init dawn                                                    || exit /b 1
  call git -C dawn remote add origin %REPO_URL% || exit /b 1
)

rem call git -C dawn fetch --no-recurse-submodules origin %DAWN_COMMIT% || exit /b 1
call git -C dawn fetch origin %DAWN_COMMIT%                         || exit /b 1
call git -C dawn reset --hard FETCH_HEAD                            || exit /b 1

if exist dawn\third_party\directx-shader-compiler\src call git -C dawn\third_party\directx-shader-compiler\src reset --hard HEAD || exit /b 1

echo DAWN CLONED!
