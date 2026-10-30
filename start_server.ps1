# 친구 시험용 서버 켜기: Docker 스택(서버·DB·Redis) + ngrok 공개 주소.
#
#   .\start_server.ps1          켜기 (이미 켜져 있으면 상태만 확인)
#   .\start_server.ps1 -Stop    끄기 (데이터는 그대로 남음)
#   .\start_server.ps1 -WebLink 켜고, 웹으로 바로 열리는 임시 링크도 만들어 줌 (가입 불필요,
#                               ngrok 안내 화면 없음, 주소는 켤 때마다 바뀜 -> 새 링크를 보내면 됨)
#
# 이 PC가 켜져 있고 이 스크립트가 돌고 있는 동안만 친구가 접속할 수 있다.
# 비밀값은 prod.env (git 에 안 올라감), ngrok 로그인은 ngrok config add-authtoken 으로 한 번 등록.

param([switch]$Stop, [switch]$WebLink)

Set-Location $PSScriptRoot
$compose = @('compose', '-f', 'docker-compose.prod.yml', '--env-file', 'prod.env')
$ngrokExe = 'C:\Users\wooritalk\tools\ngrok\ngrok.exe'

if ($Stop) {
    Get-Process ngrok, cloudflared -ErrorAction SilentlyContinue | Stop-Process -Force
    & docker @compose stop
    Write-Host '서버를 껐어요. (데이터는 남아 있어요)'
    return
}

if (-not (Test-Path 'prod.env')) { throw 'prod.env 가 없어요.' }
$domainLine = Select-String -Path 'prod.env' -Pattern '^NGROK_DOMAIN=(.+)$'
if (-not $domainLine) { throw 'prod.env 에 NGROK_DOMAIN 이 비어 있어요.' }
$domain = $domainLine.Matches[0].Groups[1].Value.Trim()

# 1) Docker 엔진
& docker info *> $null
if ($LASTEXITCODE -ne 0) {
    Write-Host 'Docker Desktop 을 켜는 중...'
    Start-Process 'C:\Program Files\Docker\Docker\Docker Desktop.exe'
    for ($i = 0; $i -lt 60; $i++) {
        Start-Sleep 3
        & docker info *> $null
        if ($LASTEXITCODE -eq 0) { break }
    }
    if ($LASTEXITCODE -ne 0) { throw 'Docker 가 3분 안에 안 켜졌어요.' }
}

# 2) 서버·DB·Redis (시작 때 마이그레이션 + 문제 동기화까지 자동)
& docker @compose up -d --build
if ($LASTEXITCODE -ne 0) { throw 'docker compose 실패' }

# 3) 서버가 살아날 때까지
$up = $false
for ($i = 0; $i -lt 40; $i++) {
    try { if ((Invoke-RestMethod -TimeoutSec 3 http://127.0.0.1:8000/healthz).status -eq 'ok') { $up = $true; break } } catch { Start-Sleep 2 }
}
if (-not $up) { throw '서버가 안 떴어요. docker compose -f docker-compose.prod.yml logs backend 를 보세요.' }

# 4) ngrok (이미 떠 있으면 그대로 둠)
if (-not (Get-Process ngrok -ErrorAction SilentlyContinue)) {
    Start-Process $ngrokExe -ArgumentList "http 8000 --url https://$domain" -WindowStyle Minimized
    Start-Sleep 5
}

# 5) 바깥 주소로 실제 접속 확인
$public = "https://$domain"
try {
    $r = Invoke-WebRequest -UseBasicParsing -TimeoutSec 10 -Headers @{ 'ngrok-skip-browser-warning' = '1' } "$public/healthz"
    Write-Host "OK  $public  (응답 $($r.StatusCode): $($r.Content))"
} catch {
    Write-Warning "서버는 떴는데 $public 로는 아직 안 열려요. ngrok authtoken 등록을 확인하세요: $ngrokExe config add-authtoken 토큰"
}

# 6) 웹 전용 임시 링크 (Cloudflare 임시 터널)
if ($WebLink) {
    $cf = 'C:\Users\wooritalk\tools\cloudflared\cloudflared.exe'
    $cfLog = 'C:\Users\wooritalk\tools\cloudflared\tunnel.log'
    Get-Process cloudflared -ErrorAction SilentlyContinue | Stop-Process -Force
    Remove-Item $cfLog -ErrorAction SilentlyContinue
    Start-Process $cf -ArgumentList @('tunnel', '--url', 'http://localhost:8000', '--no-autoupdate', '--logfile', $cfLog) -WindowStyle Hidden
    $link = $null
    for ($i = 0; $i -lt 40 -and -not $link; $i++) {
        Start-Sleep 1
        if (Test-Path $cfLog) {
            $m = Select-String -Path $cfLog -Pattern 'https://[a-z0-9-]+\.trycloudflare\.com' | Select-Object -First 1
            if ($m) { $link = $m.Matches[0].Value }
        }
    }
    if ($link) { Write-Host "웹 링크 (폰/PC 브라우저에서 열기): $link" }
    else { Write-Warning "웹 링크를 못 만들었어요. $cfLog 를 확인하세요." }
}