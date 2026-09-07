$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
Push-Location $Root
try {
  & python tools/api_readonly_smoke.py
  exit $LASTEXITCODE
} finally {
  Pop-Location
}
