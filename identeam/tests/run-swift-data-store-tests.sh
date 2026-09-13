#!/bin/bash
set -euo pipefail
project_dir="$(cd "$(dirname "$0")/.." && pwd)"
test_dir="$(mktemp -d)"
trap 'rm -rf "$test_dir"' EXIT
framework_dir="$(xcode-select -p)/Platforms/MacOSX.platform/Developer/Library/Frameworks"
swift_lib_dir="$(xcode-select -p)/Platforms/MacOSX.platform/Developer/usr/lib"
xcrun swiftc -module-cache-path "$test_dir/module-cache" \
    -I "$swift_lib_dir" -L "$swift_lib_dir" -Xlinker -rpath -Xlinker "$swift_lib_dir" \
    -F "$framework_dir" -Xlinker -rpath -Xlinker "$framework_dir" \
    -Xlinker -rpath -Xlinker "$framework_dir/../PrivateFrameworks" \
    "$project_dir/identeam/App/SwiftDataStore.swift" \
    "$project_dir/tests/SwiftDataStoreTests.swift" \
    -o "$test_dir/SwiftDataStoreTests"
"$test_dir/SwiftDataStoreTests"
