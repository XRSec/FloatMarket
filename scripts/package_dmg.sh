#!/bin/zsh

set -euo pipefail

APP_NAME="$1"
APP_PATH="$2"
DMG_NAME="$3"
DMG_TEMP_DIR="$4"
DMG_ASSETS_DIR="${5:-}"

APP_BUNDLE_NAME="$(basename "$APP_PATH")"
RW_DMG="${DMG_TEMP_DIR}.rw.dmg"
MOUNT_POINT="/Volumes/${APP_NAME}"
DEVICE_NAME=""

cleanup() {
    set +e
    if [[ -n "${DEVICE_NAME}" ]]; then
        hdiutil detach "${DEVICE_NAME}" -quiet >/dev/null 2>&1 || true
    elif [[ -d "${MOUNT_POINT}" ]]; then
        hdiutil detach "${MOUNT_POINT}" -force -quiet >/dev/null 2>&1 || true
    fi
    rm -f "${RW_DMG}"
    rm -rf "${DMG_TEMP_DIR}"
}

trap cleanup EXIT

hdiutil detach "${MOUNT_POINT}" -force -quiet >/dev/null 2>&1 || true

rm -rf "${DMG_TEMP_DIR}"
mkdir -p "${DMG_TEMP_DIR}"

cp -R "${APP_PATH}" "${DMG_TEMP_DIR}/"
ln -s /Applications "${DMG_TEMP_DIR}/Applications"

if [[ -n "${DMG_ASSETS_DIR}" && -d "${DMG_ASSETS_DIR}" ]]; then
    rsync -a --prune-empty-dirs \
        --include='*/' \
        --include='.*' \
        --exclude='*' \
        "${DMG_ASSETS_DIR}/" "${DMG_TEMP_DIR}/"
fi

rm -f "${DMG_NAME}" "${RW_DMG}"

hdiutil create \
    -volname "${APP_NAME}" \
    -srcfolder "${DMG_TEMP_DIR}" \
    -ov \
    -format UDRW \
    "${RW_DMG}" \
    >/dev/null

DEVICE_NAME="$(
    hdiutil attach -readwrite -noverify -noautoopen "${RW_DMG}" |
        awk '/\/Volumes\// { print $1; exit }'
)"

if [[ -z "${DEVICE_NAME}" ]]; then
    echo "Failed to mount writable DMG." >&2
    exit 1
fi

BACKGROUND_ALIAS=""
if [[ -d "${MOUNT_POINT}/.background" ]]; then
    for background_file in "${MOUNT_POINT}"/.background/*(N); do
        if [[ -f "${background_file}" ]]; then
            BACKGROUND_ALIAS=".background:$(basename "${background_file}")"
            break
        fi
    done
fi

osascript <<EOF
tell application "Finder"
    tell disk "${APP_NAME}"
        open
        delay 0.5
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {120, 120, 660, 450}
        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 128
        set text size of viewOptions to 12
        if "${BACKGROUND_ALIAS}" is not "" then
            set background picture of viewOptions to file "${BACKGROUND_ALIAS}"
        end if
        set position of item "${APP_BUNDLE_NAME}" of container window to {145, 130}
        set position of item "Applications" of container window to {382, 130}
        close
        open
        update without registering applications
        delay 1
    end tell
end tell
EOF

sync
hdiutil detach "${DEVICE_NAME}" -quiet >/dev/null
DEVICE_NAME=""

hdiutil convert \
    "${RW_DMG}" \
    -format UDZO \
    -imagekey zlib-level=9 \
    -o "${DMG_NAME}" \
    >/dev/null
