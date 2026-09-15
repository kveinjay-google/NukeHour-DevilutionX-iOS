# NukeHour DevilutionX iOS Task Status

Status date: 2026-09-15

## Current objective

Publish the audited iOS 1.6.0 source snapshot and immutable source tag.

## Completed

- Project version-control documentation established on 2026-09-15.
- Desktop source snapshot copied without modifying the original.
- Public-release audit passed with no signing material or game-data archives.
- Public repository and immutable source tag prepared for iOS 1.6.0.

## Active

- Maintain the published source-to-artifact mapping for subsequent versions.

## Next

- Keep future binary releases mapped to an exact source commit and immutable tag.

## Blockers

- None.

## Verification evidence

- Standard documentation generated on 2026-09-15.
- `bash scripts/audit-public-release.sh` passed on 2026-09-15 and remains the publication gate.
