$ErrorActionPreference = 'Stop'

$ProjectDirectory = Split-Path -Parent $PSScriptRoot
$RustDirectory = Join-Path $ProjectDirectory 'rust'
$NativeDirectory = Join-Path $ProjectDirectory 'app\windows\native'
$BridgeCrate = 'orchestration-ffi'
$LibraryFileName = 'orchestration_ffi.dll'

if (-not $env:CARGO_TARGET_DIR) {
    $env:CARGO_TARGET_DIR = Join-Path $RustDirectory 'target'
}

cargo build `
    --manifest-path (Join-Path $RustDirectory 'Cargo.toml') `
    --release `
    --package $BridgeCrate
if ($LASTEXITCODE -ne 0) {
    throw "cargo build failed with exit code $LASTEXITCODE"
}

New-Item -ItemType Directory -Force -Path $NativeDirectory | Out-Null
$BuiltLibrary = Join-Path $env:CARGO_TARGET_DIR "release\$LibraryFileName"
Copy-Item $BuiltLibrary (Join-Path $NativeDirectory $LibraryFileName)

Write-Output "windows library: $(Join-Path $NativeDirectory $LibraryFileName)"
