#!/bin/bash
set -eu
ROOT="$(cd "$(dirname "$0")" && pwd)"
SDK="$(xcrun --show-sdk-path)"
STAGE="$(mktemp -d "$ROOT/.build-stage.XXXXXX")"
trap 'rm -rf "$STAGE"' EXIT
APP="$STAGE/随手译.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$ROOT/.checks/cache"
for ARCH in arm64 x86_64; do
    swiftc -sdk "$SDK" -module-cache-path "$ROOT/.checks/cache" -swift-version 5 -target "$ARCH-apple-macos26.0" -framework AppKit -framework ApplicationServices -framework Carbon -framework Vision -framework Translation -framework NaturalLanguage -o "$STAGE/TransLite-$ARCH" "$ROOT/Sources/"*.swift
done
lipo -create "$STAGE/TransLite-arm64" "$STAGE/TransLite-x86_64" -output "$APP/Contents/MacOS/TransLite"
cp "$ROOT/Resource/Info.plist" "$APP/Contents/Info.plist"
for FILE in "$ROOT/Distribution/THIRD-PARTY-NOTICES.md" "$ROOT/Distribution/dependencies.json"; do
    if [ -f "$FILE" ]; then cp "$FILE" "$APP/Contents/Resources/"; fi
done
KC="${SUISHOUYI_SIGNING_KEYCHAIN:-$HOME/Library/Keychains/suishouyi-signing.keychain-db}"
IDENTITY="${SUISHOUYI_SIGNING_IDENTITY:-Suishouyi Local Signing}"
if [ -f "$KC" ]; then
    codesign --force --keychain "$KC" --sign "$IDENTITY" "$APP" || {
        echo "签名失败。请解锁原签名钥匙串后重试；旧 App 已保留。" >&2
        exit 1
    }
else
    codesign --force --sign "$IDENTITY" "$APP" || {
        echo "没有可用的稳定签名身份。请设置 SUISHOUYI_SIGNING_IDENTITY；旧 App 已保留。" >&2
        exit 1
    }
fi
SIGNING=stable
codesign --verify --deep --strict "$APP"
mkdir -p "$ROOT/Build"
if [ -d "$ROOT/Build/随手译.app" ]; then
    PREVIOUS="$ROOT/Build/随手译-previous-$(date +%Y%m%d-%H%M%S).app"
    mv "$ROOT/Build/随手译.app" "$PREVIOUS"
fi
mv "$APP" "$ROOT/Build/随手译.app"
printf 'BUILD PASS: %s (universal; signing=%s)\n' "$ROOT/Build/随手译.app" "$SIGNING"
