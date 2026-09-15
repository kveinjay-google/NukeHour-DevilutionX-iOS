# DevilutionX iOS audit

Status of the official tree plus this branch's platform layer. Labels: `IMPLEMENTED`, `BUILD VERIFIED`, `SIMULATOR VERIFIED`, `DEVICE VERIFIED`, `NOT VERIFIED`, `BLOCKED`.

Upstream: [diasurgical/devilutionX](https://github.com/diasurgical/devilutionX) `master` @ `cefa2c511d65cd424098dfe3c9782554a3f0572b` (`1.6.0-dev`). Branch: `ios-production`.

## Official iOS surface (reused)

| Area | Location | Status |
|---|---|---|
| Toolchain | `CMake/platforms/ios.toolchain.cmake`, `CMake/platforms/ios.cmake` | `IMPLEMENTED` |
| CI IPA | `.github/workflows/iOS.yml` (`PLATFORM=OS64`, Unix Makefiles) | `IMPLEMENTED` |
| Bundle | `Packaging/apple/Info.plist` (iPhone+iPad, landscape only, File Sharing, `.mpq` document type) | `IMPLEMENTED` |
| Paths | `Source/platform/ios/ios_paths.m` | `IMPLEMENTED` |
| Touch | `Source/controls/touch/` (`SDL_FingerID`) | `IMPLEMENTED` |
| Gamepad / key+mouse | SDL GameController + `UIApplicationSupportsIndirectInputEvents` | `IMPLEMENTED` |
| Min OS | iOS 16.3 (`DEPLOYMENT_TARGET`) | `IMPLEMENTED` |
| SDL | FetchContent SDL2 2.32.8, Metal renderer | `SIMULATOR VERIFIED` + `DEVICE VERIFIED` (`SDL_GetRendererInfo` name=`metal`) |

## Builds

| Target | Dir | Result |
|---|---|---|
| Simulator Debug `SIMULATORARM64` | `build-ios-sim/` | `BUILD VERIFIED` + `SIMULATOR VERIFIED` (main menu with imported `DIABDAT.MPQ`) |
| Device Release `OS64` | `build-ios-device/` | `BUILD VERIFIED` |
| IPA | `build-ios-device/devilutionx-iOS.ipa` | `BUILD VERIFIED` (development-signed, 8.4 MB) |
| Device install | iPhone 17 Pro Max `<device-id>` | `DEVICE VERIFIED` using a historical personal-team bundle identifier; the published unsigned artifact must be re-signed with an identifier controlled by the installer |
| iPad Air M4 `<device-id>` | paired, tunnel down | `NOT VERIFIED` |

Host: Xcode 26.6, iOS SDK 26.5, CMake 4.3.2, Apple Silicon. **Unix Makefiles only** — the Xcode generator failed to link FetchContent static libs.

## Gaps closed on `ios-production`

| Gap | Fix | Status |
|---|---|---|
| No native MPQ import | `UIDocumentPickerViewController` + MPQ header/name checks | `IMPLEMENTED` (copy-into-Documents path `SIMULATOR VERIFIED`) |
| `InsertCDDlg` is fatal | Native Import / Quit loop; cancel no longer fatal-exits | `IMPLEMENTED` |
| Pref/config/saves all in Documents | Saves+ini → Application Support with non-destructive migrate; MPQs stay in Documents | `IMPLEMENTED` |
| SDL_APP lifecycle dropped | Background/foreground/low-memory handled | `IMPLEMENTED` |
| AVAudioSession vs SDL CoreAudio | Activate session **after** `snd_init`; Simulator uses dummy audio (host CoreAudio hang) | `IMPLEMENTED`; device CoreAudio path used (`NOT VERIFIED` by ear) |
| Virtual pad vs notch | HUD shifted by safe-area insets; game stays full-screen | `DEVICE VERIFIED` insets `L=68 T=0 R=68 B=22`; pad drawn in Tristram |
| ProMotion 120 Hz pacing | Cap `refreshDelay` at 60 | `IMPLEMENTED` |
| CJK locale without `fonts.mpq` | Fall back to English (no blocking dialog) | `SIMULATOR VERIFIED` |
| Window-focus pause on iOS | Default `pauseOnFocusLoss=false`; background uses `SDL_APP_*` | `IMPLEMENTED` |
| Simulator docs `SIMULATOR64` / `CMake/Platforms/` | `docs/building.md` + `Packaging/ios/*.sh` | `IMPLEMENTED` |
| iOS icon is `.icns` | P2; does not block IPA | known debt |

## Runtime evidence (Simulator iPhone 17 Pro)

- Video driver `uikit`, renderer `metal`, drawable `2622x1206`
- Legal `DIABDAT.MPQ` in Documents → Blizzard splash → Diablo cinematic → **main menu** (Single Player / Multi Player / Settings)
- Version string `1.6.0-dev-Debug-cefa2c511`

## Runtime evidence (iPhone 17 Pro Max, 2026-08-19)

- Sideload identifier controlled by the tester, placeholder team `YOURTEAMID`, and placeholder identity `Apple Development: Your Name (XXXXXXXXXX)`
- Video driver `uikit`, renderer `metal`, drawable `2868x1320`, window `956x440`, safe area `L=68 T=0 R=68 B=22`
- `DIABDAT.MPQ` (493.5 MB) in Documents via `devicectl device copy to`; `Shareware=0` in `diablo.ini`
- Screenshot: Warrior in Tristram, virtual pad + classic HUD; save `single_0.sv` written under Application Support
- Repeatable install: `./Packaging/ios/sideload-device.sh`

## Risks

- The published `com.nukehour.ios` identifier may not be provisionable by another Apple account; the sideload helper rewrites it to a unique identifier controlled by the tester.
- Do not commit MPQs or certificates.
- Simulator always exposes a virtual `Gamepad`; default Virtual Gamepad mode is **Always** on Simulator, **Auto** on device.
