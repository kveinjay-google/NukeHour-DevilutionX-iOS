# NukeHour DevilutionX iOS Architecture

## System boundary

This repository owns the Nuke Hour iOS modifications, source documentation, and release audit around the DevilutionX engine. Commercial Diablo and Hellfire data, Apple credentials, provisioning profiles, signed applications, and end-user accounts remain outside the repository.

## Components

- `Source/`, `CMake/`, `Packaging/`, and platform projects: the inherited DevilutionX engine and iOS port.
- `Packaging/ios/`: repeatable iOS configuration, packaging, and personal re-sign helpers.
- `docs/ios_*.md`: architecture, build, testing, privacy, and audit evidence for the port.
- `scripts/audit-public-release.sh`: fail-closed publication checks.
- `ARTIFACTS.md`: immutable source-to-binary mapping.

## Data flow

At runtime, the user supplies legally obtained game data through the app's import flow. The engine reads those files from the app container; no commercial game archive enters this source repository or the distributed unsigned IPA.

## Runtime entry points

- `Packaging/ios/configure-simulator.sh`
- `Packaging/ios/configure-device.sh`
- `Packaging/ios/package-ipa.sh`
- `Packaging/ios/sideload-device.sh`

## Dependencies

The project uses Xcode, CMake, the iOS SDK, SDL dependencies fetched by the existing build system, and the DevilutionX international font asset. Artifact hosting and the NukeHour website are separate infrastructure.

## Decisions

- Publish this port in an independent repository to preserve a clear SUL license boundary from NukeHour's OpenRA-based projects.
- Publish only an unsigned IPA; each installer controls their own Apple signing identity and bundle identifier.
- Exclude all MPQ files from Git. `fonts.mpq` may be included only in the separately audited IPA because it is a DevilutionX font asset, not game data.
