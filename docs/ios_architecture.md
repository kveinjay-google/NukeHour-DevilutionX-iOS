# DevilutionX iOS architecture

Thin Apple platform layer on top of official DevilutionX. Game rules, assets, and the renderer stay upstream.

```text
Official DevilutionX core (game / logic / assets)
        │
        ▼
   SDL2 (FetchContent, Metal)
        │
        ▼
  UIKit / AVFoundation via SDL
        │
        ▼
  Source/platform/ios/
```

## Platform files

| File | Role |
|---|---|
| `ios_paths.m` | Documents (MPQ), Application Support (saves + `diablo.ini`), non-destructive migration |
| `ios_file_import.mm` | Missing-data alert, `UIDocumentPickerViewController`, MPQ header check, canonical names |
| `ios_platform.mm` | AVAudioSession, SDL_APP lifecycle, renderer log, safe-area insets in logical game pixels |

Hooks into core are `#ifdef __IPHONEOS__` only:

- `LoadGameArchives()` — landscape Import / Legal screen until `DIABDAT.MPQ` or `spawn.mpq` is present; Settings can import Hellfire later
- `FetchMessage_Real()` — lifecycle events; `SDL_FINGERMOTION` is not dropped
- `SpawnWindow` / `ReinitializeRenderer` — Metal hint, 60 Hz cap, HUD relayout
- `InitializeVirtualGamepad()` — shift controls by safe-area insets (not the whole framebuffer)

## Filesystem

| Kind | Location | Notes |
|---|---|---|
| Imported MPQs | `Documents/` | Files.app / Finder File Sharing |
| Saves (`*.sv`) | `Library/Application Support/diasurgical/devilution/` | Copied from Documents if dest missing |
| Config | same Application Support `diablo.ini` | Copied from Documents if dest missing |
| Caches / tmp | system Caches / tmp | not used for saves |

`GetMPQSearchPaths()` includes Documents on iOS so GOG/CD archives imported there are found.

## Display and input

- Info.plist remains landscape left/right only.
- Integer / logical scaling is unchanged; the game is not letterboxed into the safe area.
- Virtual gamepad: setting **Auto / Always / Hidden** in `diablo.ini` (`Controller.Virtual Gamepad`). Auto hides when SDL reports a gamepad (`ControlMode`).
- Keyboard and mouse on iPad go through existing SDL indirect events.

## Audio and lifecycle

- `AVAudioSessionCategoryAmbient` respects Silent Mode and mixes with other audio.
- Background: pause (unless multiplayer), deactivate session.
- Foreground / interruption end / route change: reactivate session and unpause.
- Low memory: log only; no persistent saves or GPU backbuffer are discarded.

## What this branch does not do

- No custom Metal renderer
- No Diablo rule / art changes
- No bundled `DIABDAT.MPQ` / Hellfire
- No App Store signing identities in git
