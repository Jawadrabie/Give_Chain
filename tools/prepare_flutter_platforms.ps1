$ErrorActionPreference = 'Stop'
Set-Location (Join-Path $PSScriptRoot '..')
if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
  throw 'Flutter SDK غير موجود في PATH'
}
flutter create . --platforms=android,ios,web --org com.givechain --project-name give_chain_app
flutter pub get
