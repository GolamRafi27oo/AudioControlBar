#!/bin/bash
# ============================================================
# AudioControlBar - Build & DMG Script
# Run this on your Mac with Xcode installed
# Requirements: Xcode 15+, macOS 13+, Apple Silicon Mac
# ============================================================

set -e

APP_NAME="AudioControlBar"
BUNDLE_ID="com.audiocontrolbar.app"
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$PROJECT_DIR/build"
RELEASE_DIR="$BUILD_DIR/Release"
APP_PATH="$RELEASE_DIR/$APP_NAME.app"
DMG_NAME="${APP_NAME}.dmg"
DMG_PATH="$PROJECT_DIR/$DMG_NAME"

echo "================================================"
echo "  AudioControlBar Build Script"
echo "  Building for Apple Silicon (arm64)"
echo "================================================"
echo ""

# ---- Prerequisites check ----
if ! command -v xcodebuild &>/dev/null; then
    echo "❌ xcodebuild not found. Please install Xcode from the App Store."
    exit 1
fi

XCODE_VERSION=$(xcodebuild -version | head -1 | awk '{print $2}')
echo "✅ Xcode $XCODE_VERSION detected"
echo "✅ Building from: $PROJECT_DIR"
echo ""

# ---- Clean old build ----
echo "🧹 Cleaning previous build..."
rm -rf "$BUILD_DIR"
rm -f "$DMG_PATH"

# ---- Build ----
echo "🔨 Building $APP_NAME (Release, arm64)..."
xcodebuild \
    -project "$PROJECT_DIR/$APP_NAME.xcodeproj" \
    -scheme "$APP_NAME" \
    -configuration Release \
    -arch arm64 \
    ONLY_ACTIVE_ARCH=NO \
    BUILD_DIR="$BUILD_DIR" \
    CONFIGURATION_BUILD_DIR="$RELEASE_DIR" \
    clean build \
    | xcpretty 2>/dev/null || true

# Fallback without xcpretty
if [ ! -d "$APP_PATH" ]; then
    echo "🔨 Retrying build (without xcpretty)..."
    xcodebuild \
        -project "$PROJECT_DIR/$APP_NAME.xcodeproj" \
        -scheme "$APP_NAME" \
        -configuration Release \
        -arch arm64 \
        ONLY_ACTIVE_ARCH=NO \
        BUILD_DIR="$BUILD_DIR" \
        CONFIGURATION_BUILD_DIR="$RELEASE_DIR" \
        clean build
fi

if [ ! -d "$APP_PATH" ]; then
    echo "❌ Build failed! App not found at: $APP_PATH"
    echo "   Check the Xcode build log above for errors."
    exit 1
fi

echo "✅ Build succeeded: $APP_PATH"
echo ""

# ---- Code Sign (ad-hoc if no developer account) ----
echo "🔐 Code signing..."
if xcrun codesign --sign - --force --deep --timestamp=none "$APP_PATH" 2>/dev/null; then
    echo "✅ Ad-hoc signed (works on your Mac)"
else
    echo "⚠️  Signing skipped (app will still run on your Mac)"
fi
echo ""

# ---- Create DMG ----
echo "📦 Creating DMG..."

STAGING_DIR="$BUILD_DIR/dmg-staging"
mkdir -p "$STAGING_DIR"
cp -R "$APP_PATH" "$STAGING_DIR/"

# Create symlink to /Applications
ln -sf /Applications "$STAGING_DIR/Applications"

# Create DMG using hdiutil
hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$STAGING_DIR" \
    -ov \
    -format UDZO \
    -fs HFS+ \
    "$DMG_PATH"

if [ -f "$DMG_PATH" ]; then
    DMG_SIZE=$(du -sh "$DMG_PATH" | cut -f1)
    echo "✅ DMG created: $DMG_PATH ($DMG_SIZE)"
else
    echo "❌ DMG creation failed"
    exit 1
fi

echo ""
echo "================================================"
echo "  ✅ Build Complete!"
echo "================================================"
echo ""
echo "  App:  $APP_PATH"
echo "  DMG:  $DMG_PATH"
echo ""
echo "  To install: Open the DMG and drag to Applications"
echo "  To run now: open \"$APP_PATH\""
echo ""

# ---- Ask to open/run ----
read -p "  Open app now? (y/n): " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    open "$APP_PATH"
    echo "  🎉 AudioControlBar launched! Look for the speaker icon in your menu bar."
fi

read -p "  Open DMG folder? (y/n): " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    open -R "$DMG_PATH"
fi
