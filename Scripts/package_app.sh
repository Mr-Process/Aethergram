#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${ROOT_DIR}"

if [ -f "version.env" ]; then
    source "version.env"
else
    APP_NAME="Materialgram"
    BUNDLE_ID="io.github.kukuruzka165.materialgram"
    MARKETING_VERSION="7.3.1.1"
    CURRENT_PROJECT_VERSION="7311"
    EXECUTABLE_NAME="MaterialgramMac"
fi

CONFIG="${1:-debug}"
echo "==> Packaging ${APP_NAME} (${CONFIG}) v${MARKETING_VERSION}..."

swift build -c "${CONFIG}"

BIN_PATH="${ROOT_DIR}/.build/${CONFIG}/${EXECUTABLE_NAME}"
if [ ! -f "${BIN_PATH}" ]; then
    echo "Error: Binary not found at ${BIN_PATH}" >&2
    exit 1
fi

BUILD_DIR="${ROOT_DIR}/build"
APP_BUNDLE="${BUILD_DIR}/${APP_NAME}.app"
CONTENTS_DIR="${APP_BUNDLE}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

rm -rf "${APP_BUNDLE}"
mkdir -p "${MACOS_DIR}" "${RESOURCES_DIR}"

cp "${BIN_PATH}" "${MACOS_DIR}/${APP_NAME}"
chmod +x "${MACOS_DIR}/${APP_NAME}"

# Copy resource bundles if generated
find "${ROOT_DIR}/.build/${CONFIG}" -name "*.bundle" -maxdepth 1 -exec cp -R {} "${RESOURCES_DIR}/" \; 2>/dev/null || true

# Generate Info.plist
cat <<EOF > "${CONTENTS_DIR}/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key>
    <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${MARKETING_VERSION}</string>
    <key>CFBundleVersion</key>
    <string>${CURRENT_PROJECT_VERSION}</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
EOF

# Ad-hoc sign bundle
codesign --force --deep --sign - "${APP_BUNDLE}" 2>/dev/null || true

echo "==> Successfully packaged: ${APP_BUNDLE}"
