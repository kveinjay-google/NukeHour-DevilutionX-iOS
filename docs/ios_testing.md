# iOS testing

Published unsigned bundle id: `com.nukehour.ios`. Personal-team sideload default: `com.nukehour.ios.personal`; each tester should use a unique identifier controlled by their Apple account. Orientations: landscape left/right only.

## Test A — playable loop (P0)

1. Launch with no MPQ → native explanation → **Import Game Data** or **Quit**. Canceling the picker returns to that prompt (the app does not fatal-exit).
2. Import a legal `DIABDAT.MPQ` (or `spawn.mpq`). Header must be `MPQ\x1a` / `MPQ\x1b`.
3. Main menu → new Warrior → town.
4. Enter dungeon, fight, open inventory / belt / spells / map.
5. Save → force-quit → relaunch → Load.

Expected: `DEVICE VERIFIED` on a development-signed iPhone. Simulator may complete the same loop (`SIMULATOR VERIFIED`).

## Test B — lifecycle / audio

1. Home button / app switcher during town: game pauses, audio stops, no busy loop.
2. Return: picture and audio restore (including after Silent Mode, a call, or AirPods route change).
3. Lock and unlock: no black framebuffer, input still works, save still loads.

## Test C — display / touch

1. Notch / Dynamic Island / Home Indicator: world is full-screen; virtual pad sits inside the safe area.
2. Rotate landscape left ↔ right: HUD relayouts, no persistent black bars in the wrong corner.
3. Left stick move + right-side attack with two fingers (`SDL_FingerID`).

## Test D — gamepad (optional)

Connect an MFi / SDL-supported controller. **Auto** hides the virtual pad; **Always** / **Hidden** follow Settings → Controller → Virtual Gamepad.

Without a controller attached: `NOT VERIFIED`.

## Test E — iPad key+mouse

Trackpad/keyboard use SDL indirect events. Without an iPad: `NOT VERIFIED`. If an iPad is connected, run Test A plus pointer taps in menus.

## Results (2026-08-19)

| Test | Result |
|---|---|
| A launch + MPQ in Documents → main menu | `SIMULATOR VERIFIED` (iPhone 17 Pro sim); `DEVICE VERIFIED` (iPhone 17 Pro Max, historical personal-test bundle identifier) |
| A create warrior / town / save | `DEVICE VERIFIED` — Tristram with virtual pad; `single_0.sv` (74 KB) in Application Support |
| A load after force-quit | `NOT VERIFIED` (needs one Load tap after relaunch) |
| Native document picker UI | `IMPLEMENTED` (not exercised; MPQ copied with `devicectl device copy to`) |
| B lifecycle / audio on device | `NOT VERIFIED` (app running; Home/lock/route-change not scripted) |
| C safe-area HUD | `DEVICE VERIFIED` insets logged `L=68 T=0 R=68 B=22` on 2868×1320 Metal drawable; virtual pad visible in town. 4:3 pillarbox from Fit-to-Screen is expected. |
| D physical gamepad | `NOT VERIFIED` |
| E iPad key+mouse | `NOT VERIFIED` (iPad Air M4 paired but tunnel disconnected) |

## Labels

Every result is one of: `IMPLEMENTED`, `BUILD VERIFIED`, `SIMULATOR VERIFIED`, `DEVICE VERIFIED`, `NOT VERIFIED`, `BLOCKED`.
