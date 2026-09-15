#!/bin/sh
# Resign the OS64 app with a personal-team bundle id and install it.
#
# The distributed unsigned IPA uses com.nukehour.ios. A different Apple
# Developer account normally needs its own unique identifier when re-signing.
#
# Env:
#   IOS_DEVICE                 CoreDevice UUID / UDID / name (optional; first iPhone)
#   IOS_CODE_SIGN_IDENTITY     defaults to the first Apple Development identity in the keychain
#   IOS_MOBILEPROVISION        defaults to the Xcode-generated personal profile
#   IOS_BUNDLE_ID              default com.nukehour.ios.personal
#   IOS_TEAM_ID                optional; used to find a wildcard provisioning profile
#   IOS_MPQ                    optional path; copied into Documents after install

set -eu
. "$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)/common.sh"

APP_SRC="${1:-$IOS_ROOT/build-ios-device/devilutionx.app}"
BUNDLE_ID="${IOS_BUNDLE_ID:-com.nukehour.ios.personal}"
IDENTITY="${IOS_CODE_SIGN_IDENTITY:-}"
if [ -z "$IDENTITY" ]; then
	IDENTITY="$(security find-identity -v -p codesigning 2>/dev/null | awk -F'\"' '/Apple Development/ { print $2; exit }' || true)"
fi
ENTITLEMENTS="$IOS_ROOT/Packaging/ios/sideload.entitlements"
PROFILE="${IOS_MOBILEPROVISION:-}"
DEVICE="${IOS_DEVICE:-}"

if [ ! -d "$APP_SRC" ]; then
	echo "error: $APP_SRC not found. Build the device target first." >&2
	exit 1
fi

if [ -z "$PROFILE" ]; then
	for cand in "$HOME/Library/Developer/Xcode/UserData/Provisioning Profiles/"*.mobileprovision; do
		[ -f "$cand" ] || continue
		if security cms -D -i "$cand" 2>/dev/null | grep -q "$BUNDLE_ID"; then
			PROFILE="$cand"
			break
		fi
	done
fi
if [ -z "$PROFILE" ] || [ ! -f "$PROFILE" ]; then
	if [ -n "${IOS_TEAM_ID:-}" ]; then
		for cand in "$HOME/Library/Developer/Xcode/UserData/Provisioning Profiles/"*.mobileprovision; do
			[ -f "$cand" ] || continue
			if security cms -D -i "$cand" 2>/dev/null | grep -q "${IOS_TEAM_ID}\\.\\*"; then
				PROFILE="$cand"
				break
			fi
		done
	fi
fi
if [ -z "$PROFILE" ] || [ ! -f "$PROFILE" ]; then
	echo "error: no provisioning profile for $BUNDLE_ID. Create one with Xcode automatic signing on a dummy app using that bundle id." >&2
	exit 1
fi

if [ -z "$DEVICE" ]; then
	_devjson="$(mktemp "${TMPDIR:-/tmp}/dx-devices.XXXXXX.json")"
	xcrun devicectl list devices --json-output "$_devjson" >/dev/null
	DEVICE="$(python3 -c "
import json,sys
d=json.load(open(sys.argv[1]))
devs=(d.get('result') or {}).get('devices') or []
for x in devs:
    hw=(x.get('hardwareProperties') or {})
    conn=(x.get('connectionProperties') or {})
    if hw.get('deviceType')=='iPhone' and conn.get('tunnelState')=='connected':
        print(x.get('identifier') or '')
        break
" "$_devjson" || true)"
	rm -f "$_devjson"
fi
if [ -z "$DEVICE" ]; then
	echo "error: no iPhone found. Set IOS_DEVICE." >&2
	exit 1
fi

STAGE="$(mktemp -d "${TMPDIR:-/tmp}/devilutionx-sideload.XXXXXX")"
APP="$STAGE/devilutionx.app"
trap 'rm -rf "$STAGE"' EXIT

cp -R "$APP_SRC" "$APP"
plutil -replace CFBundleIdentifier -string "$BUNDLE_ID" "$APP/Info.plist"
plutil -replace CFBundleDisplayName -string "Nuke Hour" "$APP/Info.plist"
cp "$PROFILE" "$APP/embedded.mobileprovision"
rm -rf "$APP/_CodeSignature"

echo "Signing $BUNDLE_ID with $IDENTITY"
codesign --force --sign "$IDENTITY" --entitlements "$ENTITLEMENTS" --timestamp=none --generate-entitlement-der "$APP"
codesign --verify --verbose=2 "$APP"

echo "Installing on $DEVICE"
xcrun devicectl device install app --device "$DEVICE" "$APP"

IPA="$IOS_ROOT/build-ios-device/devilutionx-iOS-sideload.ipa"
IPA_STAGE="$(mktemp -d "${TMPDIR:-/tmp}/devilutionx-sideload-ipa.XXXXXX")"
mkdir -p "$IPA_STAGE/Payload"
cp -R "$APP" "$IPA_STAGE/Payload/"
rm -f "$IPA"
(cd "$IPA_STAGE" && zip -qr "$IPA" Payload)
rm -rf "$IPA_STAGE"
echo "Wrote $IPA"

if [ -n "${IOS_MPQ:-}" ] && [ -f "$IOS_MPQ" ]; then
	echo "Copying $(basename "$IOS_MPQ") into Documents"
	xcrun devicectl device copy to \
		--device "$DEVICE" \
		--domain-type appDataContainer \
		--domain-identifier "$BUNDLE_ID" \
		--source "$IOS_MPQ" \
		--destination "Documents/$(basename "$IOS_MPQ")"
fi

echo "Launch with:"
echo "  xcrun devicectl device process launch --device '$DEVICE' --console $BUNDLE_ID"
