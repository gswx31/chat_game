# Build a release APK that talks to the given backend.
#
#   .\build_apk.ps1 -Server https://my-backend.fly.dev
#
# - The server address is baked in at build time (--dart-define=API_BASE_URL).
#   WebSocket address is derived (https -> wss). Override with -WsServer wss://...
# - Release builds are https-only (Android blocks cleartext). For a LAN/emulator
#   test use a debug build instead:  flutter run  (defaults to http://10.0.2.2:8000)
# - Signing: android\key.properties + android\upload-keystore.jks if present
#   (back these two files up! lose them and installed apps can't be updated),
#   otherwise the debug key is used.

param(
    [Parameter(Mandatory = $true)][string]$Server,
    [string]$WsServer = '',
    [switch]$SplitPerAbi
)

$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

$Server = $Server.Trim().TrimEnd('/')
if ($Server -notmatch '^https://[^/\s]+') {
    throw "Server must be an https:// address (got '$Server'). Example: -Server https://my-backend.fly.dev"
}

$buildArgs = @('build', 'apk', '--release', "--dart-define=API_BASE_URL=$Server")
if ($WsServer) {
    $buildArgs += "--dart-define=WS_BASE_URL=$($WsServer.Trim().TrimEnd('/'))"
}
if ($SplitPerAbi) {
    $buildArgs += '--split-per-abi'
}

if (Test-Path (Join-Path $PSScriptRoot 'android\key.properties')) {
    Write-Host 'Signing: release keystore (android\key.properties)'
} else {
    Write-Warning 'android\key.properties not found - signing with the DEBUG key. Fine for a quick test, but updates will not install over APKs built with a different key.'
}

Write-Host "flutter $($buildArgs -join ' ')"
& flutter @buildArgs
if ($LASTEXITCODE -ne 0) { throw "flutter build failed (exit $LASTEXITCODE)" }

$outDir = Join-Path $PSScriptRoot 'build\app\outputs\flutter-apk'
$apks = Get-ChildItem $outDir -Filter '*-release.apk' | Sort-Object Name
if (-not $apks) { throw "No release APK found in $outDir" }

Write-Host ''
foreach ($apk in $apks) {
    $mb = [math]::Round($apk.Length / 1MB, 1)
    Write-Host ("APK: {0}  ({1} MB)" -f $apk.FullName, $mb)
}
Write-Host ''
Write-Host "Server baked in: $Server"
Write-Host 'Install on a phone: send the APK (e.g. via KakaoTalk / Drive) and allow "install unknown apps".'
