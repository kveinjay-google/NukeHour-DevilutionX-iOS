# iOS performance notes

Game simulation is tick-based (`nthread`), not display-Hz. Rendering is paced separately.

## Frame rate

- Default frame-rate control is Vertical Sync (SDL Metal).
- Display refresh used for CPU-sleep pacing is **capped at 60** so a 120 Hz ProMotion panel cannot speed the game up.
- `CADisableMinimumFrameDurationOnPhone` remains set (SDL/UIKit may present at the panel rate); logic still runs at Diablo ticks.

## Memory

- `SDL_APP_LOWMEMORY` is handled. Only rebuildable caches would be eligible to drop; this branch does not discard the backbuffer, saves, or MPQ mappings.
- iOS may purge `Caches/` and `tmp`. Saves live in Application Support; MPQs in Documents.

## Profiling

Instruments (Time Profiler, Allocations, Leaks) on a Release device build:

| Tool | Result |
|---|---|
| Time Profiler | `NOT MEASURED` |
| Allocations | `NOT MEASURED` |
| Leaks | `NOT MEASURED` |
| Simulator main-menu CPU | ~4% on host while cinematic/menu running (`NOT MEASURED` as a device figure) |

To capture: Product isn't an Xcode scheme by default (Makefiles). Use `Instruments.app` → attach to `devilutionx` after `devicectl` install, or `xcrun xctrace`.

## Virtual gamepad cost

Rendering the overlay is a second pass on the SDL renderer after the upscaled game texture. Hidden/Auto+gamepad skips that pass.
