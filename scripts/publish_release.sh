#!/usr/bin/env bash
set -e

# ==============================================================================
# Fast, 100% Free Local Release Script (Zero CI Minutes Cost)
# Requirements: Flutter SDK, GitHub CLI ('gh')
# Usage: ./scripts/publish_release.sh <tag_name> [release_title]
# Example: ./scripts/publish_release.sh v1.0.0 "Initial Public Release"
# ==============================================================================

TAG="$1"
TITLE="${2:-Release $TAG}"

if [ -z "$TAG" ]; then
  echo "❌ Error: Tag name required."
  echo "Usage: $0 <tag_name> [release_title]"
  echo "Example: $0 v1.0.0 'Version 1.0.0'"
  exit 1
fi

echo "🚀 Step 1: Getting Flutter dependencies..."
flutter pub get

echo "📦 Step 2: Running code generation..."
flutter pub run build_runner build --delete-conflicting-outputs

echo "🔨 Step 3: Building Android Release APK..."
flutter build apk --release

APK_PATH="build/app/outputs/flutter-apk/app-release.apk"
OUTPUT_APK="money_manager_$TAG.apk"

if [ ! -f "$APK_PATH" ]; then
  echo "❌ Error: APK build failed or not found at $APK_PATH"
  exit 1
fi

cp "$APK_PATH" "$OUTPUT_APK"
echo "✅ APK ready at: $OUTPUT_APK"

echo "🌐 Step 4: Creating GitHub Release & uploading APK..."
gh release create "$TAG" "$OUTPUT_APK" --title "$TITLE" --generate-notes

rm -f "$OUTPUT_APK"
echo "🎉 Release $TAG published successfully with APK attached!"
