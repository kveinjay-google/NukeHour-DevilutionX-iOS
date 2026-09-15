#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
failures=0

pass() {
  printf 'PASS  %s\n' "$1"
}

fail() {
  printf 'FAIL  %s\n' "$1" >&2
  failures=$((failures + 1))
}

for required_file in README.md NOTICE.md LICENSE.md ARTIFACTS.md; do
  if [[ -s "$repo_root/$required_file" ]]; then
    pass "$required_file is present"
  else
    fail "$required_file is missing or empty"
  fi
done

mapfile_compat() {
  while IFS= read -r line; do
    [[ -n "$line" ]] && printf '%s\n' "$line"
  done
}

signing_files="$(find "$repo_root" -path "$repo_root/.git" -prune -o -type f \( \
  -iname '*.pfx' -o -iname '*.p12' -o -iname '*.mobileprovision' -o \
  -iname '*.cer' -o -iname '*.crt' -o -iname '*.key' -o -iname '*.pem' \
  \) -print | mapfile_compat)"
if [[ -z "$signing_files" ]]; then
  pass "no signing certificates, keys, or provisioning profiles"
else
  fail "signing material is present"
  printf '%s\n' "$signing_files" >&2
fi

commercial_mpqs="$(find "$repo_root" -path "$repo_root/.git" -prune -o -type f \( \
  -iname 'DIABDAT.MPQ' -o -iname 'spawn.mpq' -o -iname 'hellfire.mpq' -o \
  -iname 'hfmonk.mpq' -o -iname 'hfmusic.mpq' -o -iname 'hfvoice.mpq' \
  \) -print | mapfile_compat)"
if [[ -z "$commercial_mpqs" ]]; then
  pass "no Diablo or Hellfire game-data archives"
else
  fail "commercial or shareware game-data archives are present"
  printf '%s\n' "$commercial_mpqs" >&2
fi

if rg -n --hidden --glob '!.git/**' --glob '!scripts/audit-public-release.sh' \
  '(AKIA[0-9A-Z]{16}|-----BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY-----|re_[A-Za-z0-9_-]{24,}|sk_live_[A-Za-z0-9]{20,})' \
  "$repo_root" >/tmp/nukehour-devilutionx-secret-audit.txt; then
  fail "a credential-like value is present"
  sed -n '1,20p' /tmp/nukehour-devilutionx-secret-audit.txt >&2
else
  pass "no credential-like values"
fi

if rg -n 'set\(MACOSX_BUNDLE_GUI_IDENTIFIER com\.nukehour\.ios\)' "$repo_root/CMakeLists.txt" >/dev/null; then
  pass "iOS bundle identifier is com.nukehour.ios"
else
  fail "iOS bundle identifier is not com.nukehour.ios"
fi

if [[ -s "$repo_root/ARTIFACTS.md" ]] \
  && rg -q '75fe222aca54880533a40f852dfca91430f87c342f4fb2344ccd47fa4e481950' "$repo_root/ARTIFACTS.md" \
  && rg -q 'fonts\.mpq' "$repo_root/ARTIFACTS.md"; then
  pass "artifact checksum and fonts.mpq boundary are documented"
else
  fail "artifact checksum or fonts.mpq boundary is not documented"
fi

if (( failures > 0 )); then
  printf '\nPublic release audit failed with %d issue(s).\n' "$failures" >&2
  exit 1
fi

printf '\nPublic release audit passed.\n'
