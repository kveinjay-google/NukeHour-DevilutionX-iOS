# Building DevilutionX for iOS

Host: macOS with Xcode, CMake ≥ 3.22, Homebrew CMake is fine. SDK is whatever `xcrun --sdk iphoneos --show-sdk-version` reports; do not hardcode it.

**Generator:** Unix Makefiles (same as `.github/workflows/iOS.yml`). The Xcode generator has failed to link FetchContent static libs with CMake 4.3 + Xcode 26.

Toolchain path is `CMake/platforms/` (lowercase), not `CMake/Platforms/`.

## Scripts

From the repo root:

```bash
./Packaging/ios/configure-simulator.sh   # SIMULATORARM64 Debug → build-ios-sim
cmake --build build-ios-sim -j "$(sysctl -n hw.physicalcpu)" --config Debug

./Packaging/ios/configure-device.sh      # OS64 Release
cmake --build build-ios-device -j "$(sysctl -n hw.physicalcpu)" --config Release
./Packaging/ios/package-ipa.sh
```

Apple Silicon Simulator **must** use `SIMULATORARM64`. `SIMULATOR64` is Intel.

If FetchContent sources already exist (first Xcode-tree configure), the scripts reuse `build-ios-simulator/_deps`. Override with `DEVILUTIONX_IOS_DEPS`.

## Manual CMake

```bash
cmake -S. -Bbuild-ios-device \
  -DCMAKE_TOOLCHAIN_FILE=CMake/platforms/ios.toolchain.cmake \
  -DENABLE_BITCODE=0 -DPLATFORM=OS64
cmake --build build-ios-device -j "$(sysctl -n hw.physicalcpu)" --config Release
```

Output: `build-ios-device/devilutionx.app` and, after `package-ipa.sh`, `build-ios-device/devilutionx-iOS.ipa`.

## Signing

The public release artifact is intentionally unsigned. `package-ipa.sh` can use the first `Apple Development` identity from the local keychain when present (`IOS_CODE_SIGN_IDENTITY` overrides), but certificates and provisioning profiles must never be committed.

The published unsigned IPA and the iOS CMake target use `com.nukehour.ios`. Another Apple Developer account will normally be unable to sign that registered identifier and must replace it with a unique identifier controlled by that account.

For a development-signed sideload on a personal team, set a unique identifier before running the helper. Its default is `com.nukehour.ios.personal`, but you may still need to change it:

```bash
# First time: Xcode automatic signing on a dummy app with that bundle id
# (creates a profile that includes the connected device UDID).

export IOS_CODE_SIGN_IDENTITY='Apple Development: Your Name (XXXXXXXXXX)'
export IOS_BUNDLE_ID='com.yourname.nukehour.ios'
export IOS_MPQ="$HOME/Downloads/DIABDAT.MPQ"   # optional; copies into Documents
./Packaging/ios/sideload-device.sh
```

That script embeds the matching `.mobileprovision`, writes `build-ios-device/devilutionx-iOS-sideload.ipa`, and installs via `devicectl`. App Store distribution is out of scope.

Simulator audio: this host's CoreAudio can hang SDL's AudioQueue thread. The Simulator build forces `SDL_HINT_AUDIODRIVER=dummy`. Device builds still use CoreAudio.

## Simulator install

```bash
xcrun simctl install booted build-ios-simulator/devilutionx.app
xcrun simctl launch booted com.nukehour.ios
```

The IPA does not include Diablo or Hellfire game data. Import a legally obtained `DIABDAT.MPQ` (or the shareware `spawn.mpq`) from the first-launch prompt or **Settings → Import Game Data**, or copy it into the app Documents container (`xcrun simctl get_app_container booted com.nukehour.ios data`).

## Do not commit

`*.mpq`, `*.ipa`, `*.mobileprovision`, certificates, private keys, Apple account details, team identifiers, device identifiers, or signing exports.
