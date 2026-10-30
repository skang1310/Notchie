#!/bin/zsh
set -eu
cd "${0:A:h:h}"
source_app="${1:-../build/DynamicNotch-release/Build/Products/Release/DynamicNotch.app}"
target_app=/Applications/Notchie.app
legacy_app=/Applications/DynamicNotch.app
[[ -d "$source_app" ]] || { print -u2 "Build the Release app first."; exit 1; }
[[ -w /Applications ]] || { print -u2 "/Applications is not writable; no elevated installer is used."; exit 1; }
staging_base=$(mktemp -d /Applications/.DynamicNotch-stage.XXXXXX)
staging="${staging_base}.noindex"
mv "$staging_base" "$staging"
trap 'rmdir "$staging" 2>/dev/null || true' EXIT
ditto "$source_app" "$staging/DynamicNotch.app"
# Incremental Xcode builds may leave the retired executable beside the renamed one.
# Remove only that generated duplicate from this staged copy before signing.
staged_executable=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$staging/DynamicNotch.app/Contents/Info.plist")
if [[ "$staged_executable" == Notchie && -f "$staging/DynamicNotch.app/Contents/MacOS/DynamicNotch" ]]; then
    rm "$staging/DynamicNotch.app/Contents/MacOS/DynamicNotch"
fi
ditto LICENSE "$staging/DynamicNotch.app/Contents/Resources/DynamicNotch-GPL-3.0-LICENSE.txt"
if [[ -f LOCAL_CHANGES.md ]]; then
    ditto LOCAL_CHANGES.md "$staging/DynamicNotch.app/Contents/Resources/LOCAL_CHANGES.md"
fi
if [[ -d Vendor/HeyMac ]]; then
    mkdir -p "$staging/DynamicNotch.app/Contents/Resources/HeyMac-Notices"
    ditto Vendor/HeyMac/LICENSE "$staging/DynamicNotch.app/Contents/Resources/HeyMac-Notices/LICENSE"
    ditto Vendor/HeyMac/THIRD_PARTY_NOTICES.md "$staging/DynamicNotch.app/Contents/Resources/HeyMac-Notices/THIRD_PARTY_NOTICES.md"
    ditto Vendor/HeyMac/LOCAL_INTEGRATION.md "$staging/DynamicNotch.app/Contents/Resources/HeyMac-Notices/LOCAL_INTEGRATION.md"
fi
# Clear only signing-incompatible Finder metadata on this generated copy.
# Quarantine and all security settings are deliberately preserved.
xattr -dr com.apple.FinderInfo "$staging/DynamicNotch.app" 2>/dev/null || true
xattr -dr com.apple.ResourceFork "$staging/DynamicNotch.app" 2>/dev/null || true
signing_identity=$(security find-identity -v -p codesigning 2>/dev/null | awk '/"Apple Development:/ {print $2; exit}')
if [[ -z "$signing_identity" ]]; then
    signing_identity="-"
fi
entitlements_file="DynamicNotch/Application/DynamicNotch.entitlements"
codesign --force --deep --sign "$signing_identity" --timestamp=none "$staging/DynamicNotch.app"
if [[ -f "$entitlements_file" ]]; then
    codesign --force --sign "$signing_identity" --entitlements "$entitlements_file" --timestamp=none "$staging/DynamicNotch.app"
fi
codesign --verify --deep --strict "$staging/DynamicNotch.app"
# Validate both destinations before moving anything; retain previous installations for recovery.
for existing_app in "$target_app" "$legacy_app"; do
    if [[ -e "$existing_app" ]]; then
        current_id=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$existing_app/Contents/Info.plist")
        [[ "$current_id" == com.Jackson.DynamicNotch ]] || { print -u2 "Existing target is another app; refusing to replace it."; exit 1; }
    fi
done
mkdir -p ../build/installed-backups.noindex
for existing_app in "$target_app" "$legacy_app"; do
    if [[ -d "$existing_app" ]]; then
        backup_name="${existing_app:t:r}-$(date +%Y%m%d-%H%M%S)-${RANDOM}.app"
        mv "$existing_app" "../build/installed-backups.noindex/$backup_name"
    fi
done
# Unregister only this app's source/staging/old backup paths, never reset the registry.
lsregister=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
"$lsregister" -u "$legacy_app" 2>/dev/null || true
"$lsregister" -u "$source_app" 2>/dev/null || true
"$lsregister" -u "$staging/DynamicNotch.app" 2>/dev/null || true
for extra_app in \
    build/**/DynamicNotch.app(N) \
    ../build/**/DynamicNotch.app(N) \
    ~/Library/Developer/Xcode/DerivedData/DynamicNotch-*/Build/Products/*/DynamicNotch.app(N) \
    ../build/installed-backups.noindex/*.app(N)
do
    "$lsregister" -u "$extra_app" 2>/dev/null || true
done
mv "$staging/DynamicNotch.app" "$target_app"
"$lsregister" -f "$target_app"
print "Installed and signature verified ($signing_identity): $target_app"
