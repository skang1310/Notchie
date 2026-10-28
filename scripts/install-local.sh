#!/bin/zsh
set -eu
cd "${0:A:h:h}"
source_app="${1:-../build/DynamicNotch-release/Build/Products/Release/DynamicNotch.app}"
target_app=/Applications/DynamicNotch.app
[[ -d "$source_app" ]] || { print -u2 "Build the Release app first."; exit 1; }
[[ -w /Applications ]] || { print -u2 "/Applications is not writable; no elevated installer is used."; exit 1; }
staging_base=$(mktemp -d /Applications/.DynamicNotch-stage.XXXXXX)
staging="${staging_base}.noindex"
mv "$staging_base" "$staging"
trap 'rmdir "$staging" 2>/dev/null || true' EXIT
ditto "$source_app" "$staging/DynamicNotch.app"
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
codesign --force --deep --sign - --timestamp=none "$staging/DynamicNotch.app"
codesign --verify --deep --strict "$staging/DynamicNotch.app"
if [[ -d "$target_app" ]]; then
    current_id=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$target_app/Contents/Info.plist")
    [[ "$current_id" == com.Jackson.DynamicNotch ]] || { print -u2 "Existing target is another app; refusing to replace it."; exit 1; }
    mkdir -p ../build/installed-backups.noindex
    mv "$target_app" "../build/installed-backups.noindex/DynamicNotch-$(date +%Y%m%d-%H%M%S).app"
fi
# Unregister only this app's source/staging/old backup paths, never reset the registry.
lsregister=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
"$lsregister" -u "$source_app" 2>/dev/null || true
"$lsregister" -u "$staging/DynamicNotch.app" 2>/dev/null || true
for previous in ../build/installed-backups.noindex/*.app(N); do
    "$lsregister" -u "$previous" 2>/dev/null || true
done
mv "$staging/DynamicNotch.app" "$target_app"
"$lsregister" -f "$target_app"
print "Installed and ad-hoc signature verified: $target_app"
