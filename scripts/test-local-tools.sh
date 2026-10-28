#!/bin/zsh
# Focused model tests using the SAME source and XCTest file; no app host/permissions.
set -eu
cd "${0:A:h:h}"
staging=$(mktemp -d /tmp/DynamicNotch-tools-tests.XXXXXX)
trap 'rm -rf "$staging"' EXIT
mkdir -p "$staging/Sources/DynamicNotch" "$staging/Tests/DynamicNotchTests"
cat > "$staging/Package.swift" <<'PACKAGE'
// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "DynamicNotchLocalTools", platforms: [.macOS(.v14)], targets: [.target(name: "DynamicNotch"), .testTarget(name: "DynamicNotchTests", dependencies: ["DynamicNotch"])])
PACKAGE
for source in \
 DynamicNotch/Application/AppEnvironment.swift \
 DynamicNotch/Features/SupportDesk/SupportTextTools.swift \
 DynamicNotch/Features/SupportDesk/LocalCalculator.swift \
 DynamicNotch/Features/SupportDesk/ZipInspection.swift \
 DynamicNotch/Features/SupportDesk/ReportReconciler.swift \
 DynamicNotch/Features/SupportDesk/SupportCaseModels.swift \
 DynamicNotch/Features/SupportDesk/SupportCaseStore.swift \
 DynamicNotch/Features/SupportDesk/SupportFolderWatcher.swift \
 DynamicNotch/Features/Productivity/AppPresentationPolicy.swift \
 DynamicNotch/Features/Productivity/MeetingLink.swift \
 DynamicNotch/Features/Productivity/LocalImageConverter.swift \
 DynamicNotch/Features/Productivity/LocalJobRunner.swift \
 DynamicNotch/Features/Productivity/ProductivityStorage.swift \
 DynamicNotch/Features/Productivity/FocusSessionController.swift \
 DynamicNotch/Features/Timer/ViewModels/LocalTimerViewModel.swift \
 DynamicNotch/Features/Privacy/PrivacyPreferences.swift \
 DynamicNotch/Features/QuickTools/QuickNotes.swift \
 DynamicNotch/Features/QuickTools/Stopwatch.swift \
 DynamicNotch/Features/QuickTools/KeepAwake.swift \
 DynamicNotch/Features/QuickTools/QuickToolsStore.swift \
 DynamicNotch/Features/FaceID/Models/FaceIDState.swift \
 DynamicNotch/Features/FaceID/Services/FaceIDService.swift \
 DynamicNotch/Features/Network/VPN/Services/VPNLocationService.swift; do
 cp "$source" "$staging/Sources/DynamicNotch/"
done
cp DynamicNotchTests/Features/Settings/SecurityAndQuickToolsTests.swift "$staging/Tests/DynamicNotchTests/"
cp DynamicNotchTests/Features/Settings/ProductivityTests.swift "$staging/Tests/DynamicNotchTests/"
cp DynamicNotchTests/Features/Settings/SupportDeskCoreTests.swift "$staging/Tests/DynamicNotchTests/"
swift test --package-path "$staging"
