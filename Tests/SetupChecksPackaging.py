from pathlib import Path
import plistlib
import shutil
import subprocess
import tempfile
import xml.etree.ElementTree as ET

# 真实打包临时 universal fixture；不安装、不替换主 App。
root = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix="suishouyi-pkgcheck-") as folder:
    temporary = Path(folder)
    distribution = temporary / "Distribution"
    shutil.copytree(root / "Distribution", distribution)
    app = temporary / "Build/随手译.app"
    binary = app / "Contents/MacOS/TransLite"
    binary.parent.mkdir(parents=True)
    (app / "Contents/Resources").mkdir()
    source = temporary / "main.swift"
    source.write_text('print("packaging fixture")')
    sdk = subprocess.check_output(["xcrun", "--show-sdk-path"], text=True).strip()
    slices = []
    for arch in ["arm64", "x86_64"]:
        target = temporary / arch
        subprocess.run(["swiftc", "-sdk", sdk, "-module-cache-path", str(temporary / "modules"),
                        "-target", arch + "-apple-macos26.0", str(source), "-o", str(target)], check=True)
        slices.append(str(target))
    subprocess.run(["lipo", "-create", *slices, "-output", str(binary)], check=True)
    info = {"CFBundleIdentifier": "com.suishouyi.pkgcheck", "CFBundleExecutable": "TransLite",
            "CFBundlePackageType": "APPL", "CFBundleShortVersionString": "1.1.0", "CFBundleVersion": "110"}
    (app / "Contents/Info.plist").write_bytes(plistlib.dumps(info))
    subprocess.run(["codesign", "--force", "--sign", "-", str(app)], check=True)
    subprocess.run(["bash", str(distribution / "package-mac.sh")], check=True)
    package = temporary / "Dist/随手译-1.1.0-macOS-universal-TEST-UNSIGNED.pkg"
    assert package.exists(), "未签名包必须明确标明 TEST-UNSIGNED"
    expanded = temporary / "expanded"
    subprocess.run(["pkgutil", "--expand-full", str(package), str(expanded)], check=True)
    payload = expanded / "component.pkg/Payload/Applications/随手译.app/Contents/MacOS/TransLite"
    assert payload.exists(), "pkg 必须安装 /Applications/随手译.app"
    subprocess.run(["lipo", "-verify_arch", "arm64", str(payload)], check=True)
    subprocess.run(["lipo", "-verify_arch", "x86_64", str(payload)], check=True)
    assert ET.parse(expanded / "component.pkg/PackageInfo").getroot().get("relocatable") == "false", "不得替换其他目录中的 App"
    assert (expanded / "component.pkg/Scripts/postinstall").exists(), "pkg 缺少当前用户启动脚本"
    print("SetupChecksPackaging: 真实 pkg 构建、universal payload、安装路径和 postinstall 通过")
