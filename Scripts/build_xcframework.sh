#!/bin/bash
# FILE: Scripts/build_xcframework.sh
# Build script for CookiePrime iOS SDK XCFramework

set -e  # Exit on error

echo "📦 CookiePrime iOS SDK - XCFramework Builder"
echo "============================================"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_NAME="CookiePrimeConsent"
SCHEME_NAME="CookiePrimeConsent"
BUILD_DIR="build"
OUTPUT_DIR="."
XCFRAMEWORK_NAME="${PROJECT_NAME}.xcframework"
XCFRAMEWORK_PATH="${OUTPUT_DIR}/${XCFRAMEWORK_NAME}"

# Version from git tag or default
if [ -n "$GITHUB_REF_NAME" ]; then
    VERSION="$GITHUB_REF_NAME"
else
    VERSION=$(git describe --tags --abbrev=0 2>/dev/null || echo "1.0.0")
fi

echo -e "${BLUE}📌 Version: ${VERSION}${NC}"

# Clean previous builds
echo -e "${YELLOW}🧹 Cleaning previous builds...${NC}"
rm -rf "${BUILD_DIR}"
rm -rf "${XCFRAMEWORK_PATH}"
rm -f "${XCFRAMEWORK_NAME}.zip"

# Create build directories
mkdir -p "${BUILD_DIR}/ios"
mkdir -p "${BUILD_DIR}/ios-simulator"
mkdir -p "${BUILD_DIR}/ios-simulator-arm64"

# Check if Package.swift exists (SPM) or .xcodeproj (Xcode)
if [ -f "Package.swift" ]; then
    echo -e "${BLUE}📦 Building with Swift Package Manager...${NC}"
    
    # Build for iOS (device)
    echo -e "${YELLOW}📱 Building for iOS (device)...${NC}"
    xcodebuild archive \
        -scheme "${SCHEME_NAME}" \
        -destination "generic/platform=iOS" \
        -archivePath "${BUILD_DIR}/ios.xcarchive" \
        SKIP_INSTALL=NO \
        BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
        OTHER_SWIFT_FLAGS="-Xswiftc -enable-library-evolution" \
        | xcpretty || exit 1
    
    # Build for iOS Simulator (x86_64 + arm64)
    echo -e "${YELLOW}📱 Building for iOS Simulator...${NC}"
    xcodebuild archive \
        -scheme "${SCHEME_NAME}" \
        -destination "generic/platform=iOS Simulator" \
        -archivePath "${BUILD_DIR}/ios-simulator.xcarchive" \
        SKIP_INSTALL=NO \
        BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
        OTHER_SWIFT_FLAGS="-Xswiftc -enable-library-evolution" \
        | xcpretty || exit 1
    
else
    echo -e "${BLUE}📦 Building with Xcode project...${NC}"
    
    # Build for iOS (device)
    echo -e "${YELLOW}📱 Building for iOS (device)...${NC}"
    xcodebuild archive \
        -scheme "${SCHEME_NAME}" \
        -destination "generic/platform=iOS" \
        -archivePath "${BUILD_DIR}/ios.xcarchive" \
        SKIP_INSTALL=NO \
        BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
        | xcpretty || exit 1
    
    # Build for iOS Simulator (x86_64 + arm64)
    echo -e "${YELLOW}📱 Building for iOS Simulator...${NC}"
    xcodebuild archive \
        -scheme "${SCHEME_NAME}" \
        -destination "generic/platform=iOS Simulator" \
        -archivePath "${BUILD_DIR}/ios-simulator.xcarchive" \
        SKIP_INSTALL=NO \
        BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
        | xcpretty || exit 1
fi

# Create XCFramework
echo -e "${YELLOW}📦 Creating XCFramework...${NC}"
xcodebuild -create-xcframework \
    -framework "${BUILD_DIR}/ios.xcarchive/Products/Library/Frameworks/${PROJECT_NAME}.framework" \
    -framework "${BUILD_DIR}/ios-simulator.xcarchive/Products/Library/Frameworks/${PROJECT_NAME}.framework" \
    -output "${XCFRAMEWORK_PATH}"

# Verify XCFramework was created
if [ -d "${XCFRAMEWORK_PATH}" ]; then
    echo -e "${GREEN}✅ XCFramework created successfully!${NC}"
    echo -e "${GREEN}   📁 ${XCFRAMEWORK_PATH}${NC}"
    
    # Show framework info
    echo -e "${BLUE}📊 Framework Info:${NC}"
    du -sh "${XCFRAMEWORK_PATH}"
    find "${XCFRAMEWORK_PATH}" -name "*.framework" -type d | while read -r framework; do
        echo "   📘 $(basename "$framework")"
        # Check if it's a dynamic framework
        if [ -f "${framework}/Info.plist" ]; then
            if plutil -extract "CFBundlePackageType" raw -expect "FMWK" "${framework}/Info.plist" &>/dev/null; then
                echo "      📦 Type: Framework"
            fi
        fi
    done
else
    echo -e "${RED}❌ Failed to create XCFramework${NC}"
    exit 1
fi

# Create Info.plist for the XCFramework (if needed)
echo -e "${YELLOW}📝 Creating Info.plist...${NC}"
cat > "${XCFRAMEWORK_PATH}/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>${PROJECT_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>com.cookieprime.${PROJECT_NAME}</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>${PROJECT_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>FMWK</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundleSignature</key>
    <string>????</string>
    <key>CFBundleSupportedPlatforms</key>
    <array>
        <string>iPhoneOS</string>
    </array>
    <key>MinimumOSVersion</key>
    <string>14.0</string>
</dict>
</plist>
EOF

# Create module.modulemap if not exists
MODULEMAP_PATH="${XCFRAMEWORK_PATH}/Modules/module.modulemap"
if [ ! -f "${MODULEMAP_PATH}" ]; then
    echo -e "${YELLOW}📝 Creating module.modulemap...${NC}"
    mkdir -p "$(dirname "${MODULEMAP_PATH}")"
    cat > "${MODULEMAP_PATH}" << EOF
framework module ${PROJECT_NAME} {
    umbrella header "${PROJECT_NAME}.h"
    export *
    module * { export * }
}
EOF
fi

# Generate PrivacyInfo.xcprivacy (Apple requirement)
echo -e "${YELLOW}🔒 Generating PrivacyInfo.xcprivacy...${NC}"
mkdir -p "${XCFRAMEWORK_PATH}/Resources"
cat > "${XCFRAMEWORK_PATH}/Resources/PrivacyInfo.xcprivacy" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>NSPrivacyTracking</key>
    <false/>
    <key>NSPrivacyCollectedDataTypes</key>
    <array>
        <dict>
            <key>NSPrivacyCollectedDataType</key>
            <string>NSPrivacyCollectedDataTypeUserID</string>
            <key>NSPrivacyCollectedDataTypeLinked</key>
            <false/>
            <key>NSPrivacyCollectedDataTypeTracking</key>
            <false/>
            <key>NSPrivacyCollectedDataTypePurpose</key>
            <array>
                <string>NSPrivacyCollectedDataTypePurposeAnalytics</string>
            </array>
        </dict>
    </array>
    <key>NSPrivacyTrackingDomains</key>
    <array>
        <string>*.cookieprime.com</string>
    </array>
</dict>
</plist>
EOF

# Compress XCFramework for distribution
echo -e "${YELLOW}📦 Compressing XCFramework...${NC}"
zip -r "${XCFRAMEWORK_NAME}.zip" "${XCFRAMEWORK_PATH}" -x "*.DS_Store" -x "__MACOSX"

# Check if zip was created
if [ -f "${XCFRAMEWORK_NAME}.zip" ]; then
    echo -e "${GREEN}✅ XCFramework compressed successfully!${NC}"
    echo -e "${GREEN}   📁 ${XCFRAMEWORK_NAME}.zip${NC}"
    du -sh "${XCFRAMEWORK_NAME}.zip"
else
    echo -e "${RED}❌ Failed to compress XCFramework${NC}"
    exit 1
fi

# Generate checksum for SPM (optional)
if command -v shasum &> /dev/null; then
    CHECKSUM=$(shasum -a 256 "${XCFRAMEWORK_NAME}.zip" | awk '{ print $1 }')
    echo -e "${BLUE}🔑 SPM Checksum: ${CHECKSUM}${NC}"
    
    # Save checksum to file
    echo "${CHECKSUM}" > "${XCFRAMEWORK_NAME}.checksum"
    echo -e "${GREEN}✅ Checksum saved to ${XCFRAMEWORK_NAME}.checksum${NC}"
fi

# Generate SPM integration instructions
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}✅ Build Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e ""
echo -e "${BLUE}📦 Artifacts:${NC}"
echo -e "   📁 ${XCFRAMEWORK_PATH}"
echo -e "   📦 ${XCFRAMEWORK_NAME}.zip"
if [ -f "${XCFRAMEWORK_NAME}.checksum" ]; then
    echo -e "   🔑 ${XCFRAMEWORK_NAME}.checksum"
fi
echo -e ""
echo -e "${BLUE}📚 Integration:${NC}"
echo -e ""
echo -e "1️⃣  Swift Package Manager:"
echo -e "   Add to Package.swift:"
echo -e "   .binaryTarget("
echo -e "       name: \"${PROJECT_NAME}\","
echo -e "       path: \"${XCFRAMEWORK_NAME}.zip\""
echo -e "   )"
echo -e ""
echo -e "2️⃣  Manual Integration:"
echo -e "   - Drag ${XCFRAMEWORK_NAME} into Xcode"
echo -e "   - Add to Embedded Binaries"
echo -e "   - Add to Linked Frameworks and Libraries"
echo -e ""
echo -e "3️⃣  CocoaPods:"
echo -e "   pod '${PROJECT_NAME}', :path => '.'"
echo -e ""
echo -e "========================================${NC}"