#!/bin/sh
# Configure an Apple Silicon iOS Simulator Debug build (Unix Makefiles).
# SIMULATOR64 is Intel-only; Apple Silicon hosts must use SIMULATORARM64.

set -eu
. "$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)/common.sh"

ios_configure build-ios-sim SIMULATORARM64 -DCMAKE_BUILD_TYPE=Debug "$@"
echo "Configured $IOS_ROOT/build-ios-sim"
echo "Build with: cmake --build \"$IOS_ROOT/build-ios-sim\" -j \"\$(sysctl -n hw.physicalcpu)\" --config Debug"
