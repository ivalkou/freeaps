#!/bin/bash
# Build Dependencies as XCFrameworks
# This script builds all dependency frameworks from the original xcodeproj files
# using a temporary workspace that includes all dependency projects

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$ROOT_DIR/DerivedData/Dependencies"
XCFRAMEWORKS_DIR="$ROOT_DIR/Frameworks"
DEPS_DIR="$ROOT_DIR/Dependencies"
TEMP_WORKSPACE="$BUILD_DIR/Dependencies.xcworkspace"

# Clean previous builds
rm -rf "$BUILD_DIR"
rm -rf "$XCFRAMEWORKS_DIR"
mkdir -p "$BUILD_DIR"
mkdir -p "$XCFRAMEWORKS_DIR"

echo "Building Dependencies as XCFrameworks"
echo "Output: $XCFRAMEWORKS_DIR"
echo ""

# Create temporary workspace that includes all dependency projects
mkdir -p "$TEMP_WORKSPACE"
cat > "$TEMP_WORKSPACE/contents.xcworkspacedata" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<Workspace version="1.0">
   <FileRef location="absolute:$DEPS_DIR/LoopKit/LoopKit.xcodeproj"/>
   <FileRef location="absolute:$DEPS_DIR/rileylink_ios/RileyLink.xcodeproj"/>
   <FileRef location="absolute:$DEPS_DIR/CGMBLEKit/CGMBLEKit.xcodeproj"/>
</Workspace>
EOF

echo "Created temporary workspace at $TEMP_WORKSPACE"
echo ""

build_xcframework() {
    local framework_name=$1

    echo ""
    echo "=== Building $framework_name ==="

    # Build for iOS Simulator
    echo "Building for iOS Simulator..."
    xcodebuild archive \
        -workspace "$TEMP_WORKSPACE" \
        -scheme "$framework_name" \
        -destination "generic/platform=iOS Simulator" \
        -archivePath "$BUILD_DIR/$framework_name-simulator.xcarchive" \
        -derivedDataPath "$BUILD_DIR/DerivedData" \
        SKIP_INSTALL=NO \
        BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
        ONLY_ACTIVE_ARCH=NO \
        IPHONEOS_DEPLOYMENT_TARGET=18.0 \
        -quiet 2>&1 || {
            echo "Warning: Failed to build $framework_name for simulator"
            return 1
        }

    # Build for iOS Device
    echo "Building for iOS Device..."
    xcodebuild archive \
        -workspace "$TEMP_WORKSPACE" \
        -scheme "$framework_name" \
        -destination "generic/platform=iOS" \
        -archivePath "$BUILD_DIR/$framework_name-ios.xcarchive" \
        -derivedDataPath "$BUILD_DIR/DerivedData" \
        SKIP_INSTALL=NO \
        BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
        ONLY_ACTIVE_ARCH=NO \
        IPHONEOS_DEPLOYMENT_TARGET=18.0 \
        -quiet 2>&1 || {
            echo "Warning: Failed to build $framework_name for iOS device"
            return 1
        }

    # Create XCFramework
    local sim_framework="$BUILD_DIR/$framework_name-simulator.xcarchive/Products/Library/Frameworks/$framework_name.framework"
    local ios_framework="$BUILD_DIR/$framework_name-ios.xcarchive/Products/Library/Frameworks/$framework_name.framework"

    if [ -d "$sim_framework" ] && [ -d "$ios_framework" ]; then
        rm -rf "$XCFRAMEWORKS_DIR/$framework_name.xcframework"
        xcodebuild -create-xcframework \
            -framework "$sim_framework" \
            -framework "$ios_framework" \
            -output "$XCFRAMEWORKS_DIR/$framework_name.xcframework"

        echo "Created $framework_name.xcframework"
    else
        echo "Warning: Could not find framework products for $framework_name"
        echo "  Simulator: $sim_framework (exists: $(test -d "$sim_framework" && echo yes || echo no))"
        echo "  iOS: $ios_framework (exists: $(test -d "$ios_framework" && echo yes || echo no))"
        return 1
    fi
}

# All frameworks to build (in dependency order)
FRAMEWORKS=(
    # LoopKit (base dependencies first)
    "LoopKit"
    "LoopTestingKit"
    "MockKit"
    "LoopKitUI"
    "MockKitUI"

    # RileyLink (depends on LoopKit)
    "Crypto"
    "RileyLinkBLEKit"
    "RileyLinkKit"
    "RileyLinkKitUI"
    "MinimedKit"
    "MinimedKitUI"
    "OmniKit"
    "OmniKitUI"

    # CGMBLEKit (depends on LoopKit)
    "CGMBLEKit"
)

# Track success/failure
SUCCESSFUL=()
FAILED=()

for fw in "${FRAMEWORKS[@]}"; do
    if build_xcframework "$fw"; then
        SUCCESSFUL+=("$fw")
    else
        FAILED+=("$fw")
    fi
done

echo ""
echo "========================================="
echo "Build Summary"
echo "========================================="
echo ""
echo "Successful (${#SUCCESSFUL[@]}):"
for fw in "${SUCCESSFUL[@]}"; do
    echo "  $fw"
done

if [ ${#FAILED[@]} -gt 0 ]; then
    echo ""
    echo "Failed (${#FAILED[@]}):"
    for fw in "${FAILED[@]}"; do
        echo "  $fw"
    done
fi

echo ""
echo "XCFrameworks are in: $XCFRAMEWORKS_DIR"
ls -la "$XCFRAMEWORKS_DIR" 2>/dev/null || echo "(empty)"

# Cleanup
rm -rf "$TEMP_WORKSPACE"

if [ ${#FAILED[@]} -gt 0 ]; then
    echo ""
    echo "Some frameworks failed to build. This might be due to:"
    echo "  - Missing schemes (check with: xcodebuild -project <path> -list)"
    echo "  - Build errors in the source code"
    echo "  - Missing dependencies"
    exit 1
fi
