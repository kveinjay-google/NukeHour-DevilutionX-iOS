# Nuke Hour for iOS · DevilutionX Edition

**Modified by Nuke Hour.** Official website: https://nukehour.com

This repository publishes the source snapshot for Nuke Hour 1.6.0 on iOS, a modified version of [DevilutionX](https://github.com/diasurgical/DevilutionX). It is not the official DevilutionX project and is not provided, supported, or endorsed by Diasurgical or Blizzard Entertainment.

The corresponding IPA is unsigned and contains no Diablo or Hellfire game data. A user must re-sign it with an Apple account they control and provide a legally obtained `DIABDAT.MPQ`, or use the shareware `spawn.mpq`. The included `fonts.mpq` is the separate DevilutionX international font asset and is not commercial game data.

## Source and artifact mapping

- Release: Nuke Hour iOS 1.6.0
- Display name: `Nuke Hour`
- Bundle identifier in the unsigned artifact: `com.nukehour.ios`
- Immutable source tag: `ios-v1.6.0`
- Artifact record and checksum: [ARTIFACTS.md](ARTIFACTS.md)
- iOS build instructions: [docs/ios_build.md](docs/ios_build.md)

## License and attribution

This modified source remains under the DevilutionX Sustainable Use License. Read [LICENSE.md](LICENSE.md) and the required modification notice in [NOTICE.md](NOTICE.md) before using or redistributing it. Distribution must remain free of charge and within the license's non-commercial limitations.

## Public release audit

Run:

```sh
bash scripts/audit-public-release.sh
```

The audit rejects signing files, provisioning profiles, known game-data archives, credential-like values, an incorrect iOS bundle identifier, or incomplete artifact documentation.

## Project documentation

- [Architecture](ARCHITECTURE.md)
- [Task status](TASK.md)
- [Changelog](CHANGELOG.md)
- [Documentation index](docs/README.md)
