#!/bin/sh
# Configure an iOS device Release build (Unix Makefiles, PLATFORM=OS64).

set -eu
. "$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)/common.sh"

ios_configure build-ios-device OS64 -DCMAKE_BUILD_TYPE=Release "$@"
echo "Configured $IOS_ROOT/build-ios-device"
echo "Build with: cmake --build \"$IOS_ROOT/build-ios-device\" -j \"\$(sysctl -n hw.physicalcpu)\" --config Release"
echo "Package with: \"$IOS_ROOT/Packaging/ios/package-ipa.sh\""
