# Windows 第三方组件

- .NET 10.0.12 / Windows Desktop Runtime：Microsoft，MIT。https://github.com/dotnet/runtime/blob/main/LICENSE.TXT
- Tesseract .NET wrapper 5.2.0：Charles Weld，Apache-2.0；内含 Tesseract 5.2.0 与 Leptonica 1.82.0 x64 DLL。https://github.com/charlesw/tesseract
- Tesseract：Apache-2.0。https://github.com/tesseract-ocr/tesseract/blob/main/LICENSE
- Leptonica：BSD-2-Clause。https://github.com/DanBloomberg/leptonica/blob/master/leptonica-license.txt
- InteropDotNet：Andrey Akinshin，MIT。https://github.com/AndreyAkinshin/InteropDotNet
- tessdata_fast 4.1.0：Apache-2.0；固定 commit 65727574dfcd264acbb0c3e07860e4e9e9b22185；eng、chi_sim 实体资源随包，LICENSE 同目录。
- Microsoft Visual C++ x64 Redistributable：微软许可，仅原样再分发。首次缺失时自动运行官方安装包，Windows 可能要求确认；不要求开发工具。https://learn.microsoft.com/en-us/cpp/windows/latest-supported-vc-redist
- CodeBuddy 2.164.0：用户机器从 CodeBuddy 官方下载；SHA256 与官方 checksums.txt 核对；随手译安装包不再分发其二进制或账号资料。https://www.codebuddy.cn/docs/cli/installation

资源来源、固定版本和真实校验值：Windows/dependencies.json。未签名候选版；Windows 运行与实际 OCR 识别仍需实机验证。
