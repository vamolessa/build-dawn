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

echo "ARCH = $ARCH !!"
echo "placeholder" > dawn-mac-${PROCESSOR_ARCHITECTURE}-${BUILD_DATE}.zip
