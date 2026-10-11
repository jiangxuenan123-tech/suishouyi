#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/Build/随手译.app"
OUT="$ROOT/Dist"
VERSION=1.1.0
[[ -d "$APP" ]] || { echo '缺少 Build/随手译.app，请先运行 build.sh。' >&2; exit 1; }
/usr/bin/lipo -verify_arch arm64 "$APP/Contents/MacOS/TransLite"
/usr/bin/lipo -verify_arch x86_64 "$APP/Contents/MacOS/TransLite"
/usr/bin/plutil -extract CFBundleShortVersionString raw "$APP/Contents/Info.plist" | /usr/bin/grep -qx "$VERSION"
mkdir -p "$OUT"
STAGE=$(/usr/bin/mktemp -d)
trap '/bin/rm -rf "$STAGE"' EXIT
mkdir -p "$STAGE/payload/Applications" "$STAGE/resources"
/usr/bin/ditto "$APP" "$STAGE/payload/Applications/随手译.app"
STAGED_APP="$STAGE/payload/Applications/随手译.app"
APP_IDENTITY=${MAC_APP_SIGN_IDENTITY:-$(/usr/bin/security find-identity -v -p codesigning | /usr/bin/awk -F '"' '/Developer ID Application:/ { print $2; exit }')}
INSTALLER_IDENTITY=${MAC_INSTALLER_SIGN_IDENTITY:-$(/usr/bin/security find-identity -v | /usr/bin/awk -F '"' '/Developer ID Installer:/ { print $2; exit }')}
PROFILE=${NOTARYTOOL_PROFILE:-}
LABEL=TEST-UNSIGNED
SIGN_ARGS=()
if [[ -n "$APP_IDENTITY" && -n "$INSTALLER_IDENTITY" ]]; then
  [[ "$APP_IDENTITY" == "Developer ID Application:"* && "$INSTALLER_IDENTITY" == "Developer ID Installer:"* ]] || {
    echo '必须使用 Developer ID Application 与 Developer ID Installer 证书名称。' >&2; exit 1;
  }
  /usr/bin/codesign --force --options runtime --timestamp --sign "$APP_IDENTITY" "$STAGED_APP"
  SIGN_ARGS=(--sign "$INSTALLER_IDENTITY" --timestamp)
  LABEL=SIGNED-NOT-NOTARIZED
else
  echo '未配置 Developer ID Application/Installer：生成明确标注的未签名测试安装包。'
fi
/usr/bin/codesign --verify --deep --strict "$STAGED_APP"
/usr/bin/pkgbuild --analyze --root "$STAGE/payload" "$STAGE/components.plist"
/usr/bin/python3 - "$STAGE/components.plist" <<'PYCOMPONENT'
import plistlib, sys
from pathlib import Path
p = Path(sys.argv[1])
components = plistlib.loads(p.read_bytes())
for component in components:
    component['BundleIsRelocatable'] = False
p.write_bytes(plistlib.dumps(components))
PYCOMPONENT
/usr/bin/pkgbuild --root "$STAGE/payload" --component-plist "$STAGE/components.plist" --identifier com.suishouyi.mac --version "$VERSION" \
  --scripts "$ROOT/Distribution/mac-scripts" --install-location / "$STAGE/component.pkg"
/usr/bin/python3 - "$STAGE" "$LABEL" <<'PYDOC'
from pathlib import Path
import sys
stage, label = sys.argv[1:]
p = Path(stage)
title = '测试安装包' if label == 'TEST-UNSIGNED' else 'Developer ID 已签名'
warning = '此包未经 Developer ID 签名或 Apple 公证，仅供受控测试。macOS 可能阻止打开。' if label == 'TEST-UNSIGNED' else '使用 Developer ID 签名；是否通过 Apple 公证请查看安装包旁的状态文件。'
(p/'resources/welcome.html').write_text('<html><meta charset="utf-8"><body><h2>随手译 1.1.0</h2><p>' + warning + '</p><p>安装到 /Applications/随手译.app。安装后自动启动，自动准备官方 CodeBuddy 组件。首次登录、辅助功能和屏幕录制权限需要本人确认。</p></body></html>')
(p/'distribution.xml').write_text('''<?xml version="1.0" encoding="utf-8"?>
<installer-gui-script minSpecVersion="2">
  <title>随手译 1.1.0 · ''' + title + '''</title>
  <welcome file="welcome.html" mime-type="text/html"/>
  <options customize="never" require-scripts="false" hostArchitectures="arm64,x86_64"/>
  <domains enable_anywhere="false" enable_currentUserHome="false" enable_localSystem="true"/>
  <choices-outline><line choice="default"/></choices-outline>
  <choice id="default" title="随手译" visible="false"><pkg-ref id="com.suishouyi.mac"/></choice>
  <pkg-ref id="com.suishouyi.mac" version="1.1.0" onConclusion="none">component.pkg</pkg-ref>
</installer-gui-script>
''')
PYDOC
PACKAGE="$OUT/随手译-$VERSION-macOS-universal-$LABEL.pkg"
/usr/bin/productbuild --distribution "$STAGE/distribution.xml" --resources "$STAGE/resources" \
  --package-path "$STAGE" ${SIGN_ARGS[@]+"${SIGN_ARGS[@]}"} "$PACKAGE"
if [[ -n "$APP_IDENTITY" && -n "$INSTALLER_IDENTITY" && -n "$PROFILE" ]]; then
  /usr/bin/xcrun notarytool submit "$PACKAGE" --keychain-profile "$PROFILE" --wait --output-format json > "$STAGE/notary.json"
  /usr/bin/python3 - "$STAGE/notary.json" <<'PYNOTARY'
import json, sys
r = json.load(open(sys.argv[1]))
if r.get('status') != 'Accepted':
    raise SystemExit('Apple 公证未通过；请查看提交记录。')
PYNOTARY
  /usr/bin/xcrun stapler staple "$PACKAGE"
  /usr/bin/xcrun stapler validate "$PACKAGE"
  /usr/sbin/spctl --assess --type install -v "$PACKAGE"
  LABEL=NOTARIZED
  FINAL_PACKAGE="$OUT/随手译-$VERSION-macOS-universal-$LABEL.pkg"
  /bin/mv "$PACKAGE" "$FINAL_PACKAGE"
  PACKAGE="$FINAL_PACKAGE"
fi
/usr/sbin/pkgutil --check-signature "$PACKAGE" || [[ "$LABEL" == TEST-UNSIGNED ]]
/usr/bin/shasum -a 256 "$PACKAGE" > "$PACKAGE.sha256"
case "$LABEL" in
  TEST-UNSIGNED) STATE='测试包；未获得 Developer ID 签名和 Apple 公证，跨机器安装未验证。' ;;
  SIGNED-NOT-NOTARIZED) STATE='Developer ID 已签名；未公证，不能标记为正式分发完成。' ;;
  NOTARIZED) STATE='Developer ID 已签名；Apple 公证 Accepted；stapler 与 Gatekeeper 检查通过。' ;;
esac
/usr/bin/printf '%s\n%s\n' "随手译 $VERSION macOS universal" "$STATE" > "$PACKAGE.status.txt"
echo "安装包：$PACKAGE"
