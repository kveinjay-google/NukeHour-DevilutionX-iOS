#!/bin/sh
# Package devilutionx.app into devilutionx-iOS.ipa.
# Optionally ad-hoc or development-sign if an Apple Development identity exists.
# Does not store certificates in the repo.

set -eu
. "$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)/common.sh"

BUILD_DIR="${1:-$IOS_ROOT/build-ios-device}"
APP="$BUILD_DIR/devilutionx.app"
IPA="$BUILD_DIR/devilutionx-iOS.ipa"

if [ ! -d "$APP" ]; then
	echo "error: $APP not found. Build the device target first." >&2
	exit 1
fi

IDENTITY="${IOS_CODE_SIGN_IDENTITY:-}"
if [ -z "$IDENTITY" ]; then
	IDENTITY="$(security find-identity -v -p codesigning 2>/dev/null | awk -F'\"' '/Apple Development/ { print $2; exit }' || true)"
fi

if [ -n "${IOS_MOBILEPROVISION:-}" ] && [ -f "$IOS_MOBILEPROVISION" ]; then
	cp "$IOS_MOBILEPROVISION" "$APP/embedded.mobileprovision"
	echo "Embedded provisioning profile: $IOS_MOBILEPROVISION"
fi

if [ -n "$IDENTITY" ]; then
	echo "Signing with: $IDENTITY"
	ENTITLEMENTS="$IOS_ROOT/Packaging/ios/development.entitlements"
	if ! codesign --force --sign "$IDENTITY" --timestamp=none --entitlements "$ENTITLEMENTS" "$APP"; then
		codesign --force --sign "$IDENTITY" --timestamp=none "$APP"
	fi
	codesign --verify --verbose=2 "$APP" || true
else
	echo "No Apple Development identity found; packaging unsigned IPA."
fi

STAGE="$(mktemp -d "${TMPDIR:-/tmp}/devilutionx-ipa.XXXXXX")"
mkdir -p "$STAGE/Payload"
cp -R "$APP" "$STAGE/Payload/"
rm -f "$IPA"
(cd "$STAGE" && zip -qr "$IPA" Payload)
rm -rf "$STAGE"

echo "Wrote $IPA"
ls -lh "$IPA"
