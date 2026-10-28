#!/bin/zsh
set -eu
cd "${0:A:h:h}"
# A clean app build avoids reusing stale SwiftUI struct layouts after UI changes.
# One worker keeps a bootstrap failure from spawning several visible test hosts.
xcodebuild -project DynamicNotch.xcodeproj -scheme DynamicNotch \
  -configuration Debug -derivedDataPath build/HeyMacTests \
  DYNAMICNOTCH_TEST_HOST=YES \
  PRODUCT_BUNDLE_IDENTIFIER=com.Jackson.DynamicNotch.LocalTests \
  INFOPLIST_KEY_CFBundleDisplayName='DynamicNotch Tests' \
  CODE_SIGNING_ALLOWED=NO ENABLE_DEBUG_DYLIB=NO \
  -parallel-testing-enabled NO clean test
