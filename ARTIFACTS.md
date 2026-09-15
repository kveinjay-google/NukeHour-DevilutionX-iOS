# Published Artifacts

## Nuke Hour iOS 1.6.0

| Field | Value |
| --- | --- |
| Source tag | `ios-v1.6.0` |
| Artifact | `NukeHour-DevilutionX-iOS-1.6.0-unsigned.ipa` |
| Display name | `Nuke Hour` |
| Bundle identifier | `com.nukehour.ios` |
| Signing state | Unsigned; no embedded provisioning profile |
| Size | 71,526,083 bytes |
| SHA-256 | `75fe222aca54880533a40f852dfca91430f87c342f4fb2344ccd47fa4e481950` |

The IPA contains the engine runtime and the DevilutionX international font asset `fonts.mpq`. That archive supplies interface fonts and is not Diablo or Hellfire game data.

The IPA does not contain `DIABDAT.MPQ`, `spawn.mpq`, `hellfire.mpq`, `hfmonk.mpq`, `hfmusic.mpq`, or `hfvoice.mpq`. On first launch, a user must import a legally obtained `DIABDAT.MPQ` or use the shareware `spawn.mpq`. Optional Hellfire data must likewise be supplied legally by the user.

The artifact is not signed with a NukeHour or personal Apple identity. Each user must re-sign it with an Apple account and bundle identifier they control before installation through a compatible sideloading workflow.
