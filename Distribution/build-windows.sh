#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DOTNET="${SUISHOUYI_DOTNET:-/private/tmp/suishouyi-dotnet/dotnet}"
export DOTNET_CLI_HOME="${SUISHOUYI_DOTNET_HOME:-/private/tmp/suishouyi-dotnet-home}"
export NUGET_PACKAGES="${SUISHOUYI_NUGET:-/private/tmp/suishouyi-nuget}"
export DOTNET_CLI_TELEMETRY_OPTOUT=1
[[ -x "$DOTNET" ]] || { echo "Set SUISHOUYI_DOTNET to the .NET 10 SDK executable."; exit 1; }
"$DOTNET" run --project "$ROOT/Windows/Checks" -c Release
STAGE="$ROOT/Windows/Build/publish"
"$DOTNET" publish "$ROOT/Windows/App" -c Release -r win-x64 --self-contained true -p:NuGetAudit=false -o "$STAGE"
python3 - "$ROOT" "$STAGE" <<'PYCODE'
from pathlib import Path
import sys,zipfile,json,hashlib
root,stage=map(Path,sys.argv[1:])
required=['Suishouyi.exe','coreclr.dll','hostfxr.dll','x64/tesseract50.dll','x64/leptonica-1.82.0.dll','Resources/tessdata/chi_sim.traineddata','Resources/tessdata/eng.traineddata','Resources/vc_redist.x64.exe']
for name in required:
 assert (stage/name).is_file(),name
metadata=json.loads((root/'Windows/dependencies.json').read_text())
for r in metadata['resources']:
 relative=Path('Resources')/(Path('tessdata')/r['name'] if r['name']!='vc_redist.x64.exe' else r['name'])
 assert hashlib.sha256((stage/relative).read_bytes()).hexdigest()==r['sha256'],relative
for r in metadata['nativeOcrDLLs']:
 assert hashlib.sha256((stage/r['name']).read_bytes()).hexdigest()==r['sha256'],r['name']
with zipfile.ZipFile(root/'Windows/Installer/payload.zip','w',zipfile.ZIP_DEFLATED,compresslevel=6) as z:
 for file in stage.rglob('*'):
  if file.is_file(): z.write(file,file.relative_to(stage))
print('Windows self-contained payload and OCR hashes verified')
PYCODE
"$DOTNET" publish "$ROOT/Windows/Installer" -c Release -r win-x64 --self-contained true -p:PublishSingleFile=true -p:IncludeNativeLibrariesForSelfExtract=true -p:NuGetAudit=false -o "$ROOT/Windows/Build/setup"
mkdir -p "$ROOT/Dist"
cp "$ROOT/Windows/Build/setup/Setup.exe" "$ROOT/Dist/Suishouyi-1.2.1-windows-x64-Setup.exe"
shasum -a 256 "$ROOT/Dist/Suishouyi-1.2.1-windows-x64-Setup.exe"
