<#
.SYNOPSIS
  Wordt door Taakplanner gestart (bij aanmelden +15 min en dagelijks 9u00): laat Claude
  headless /ticket-triage draaien op de eigen open tickets. Max 1 run per werkdag.
  Plaatst enkel interne notities (deny-lijst in triage-permissions.json); nooit prod-writes.
.PARAMETER Scope
  Argument voor de skill: "mij" (standaard) of een batch "#85054295 #85029820".
.PARAMETER Force
  Negeert de weekend- en al-gedraaid-vandaag-check (manuele test).
#>
param(
    [string]$Scope = "mij",
    [switch]$Force
)
$ErrorActionPreference = "Continue"
$base    = Join-Path $env:USERPROFILE ".claude\ticket-triage"
$logDir  = Join-Path $base "logs"
$marker  = Join-Path $base "last-run.txt"
$workDir = Join-Path $env:USERPROFILE "OneDrive - EEG NV\Bureaublad"
$claude  = Join-Path $env:USERPROFILE ".local\bin\claude.exe"
New-Item -ItemType Directory -Force $logDir | Out-Null
$today = Get-Date -Format "yyyy-MM-dd"
$log   = Join-Path $logDir ("run_" + (Get-Date -Format "yyyyMMdd_HHmm") + ".log")

function Write-Log($msg) { "$(Get-Date -Format 'HH:mm:ss') $msg" | Out-File -FilePath $log -Append -Encoding utf8 }

function Show-Toast($title, $text) {
    try {
        [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
        $xml = [Windows.UI.Notifications.ToastNotificationManager]::GetTemplateContent([Windows.UI.Notifications.ToastTemplateType]::ToastText02)
        $nodes = $xml.GetElementsByTagName("text")
        $nodes.Item(0).AppendChild($xml.CreateTextNode($title)) | Out-Null
        $nodes.Item(1).AppendChild($xml.CreateTextNode($text)) | Out-Null
        $appId = '{1AC14E77-02E7-4E5D-B744-2EB1AE5198B7}\WindowsPowerShell\v1.0\powershell.exe'
        [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($appId).Show([Windows.UI.Notifications.ToastNotification]::new($xml))
    } catch { Write-Log "Melding tonen mislukt: $_" }
}

if (-not $Force) {
    if ((Get-Date).DayOfWeek -in @('Saturday', 'Sunday')) { exit 0 }
    if ((Test-Path $marker) -and ((Get-Content $marker -Raw).Trim() -eq $today)) { exit 0 }
}

# Wachten tot QA bereikbaar is (VPN/netwerk na opstarten): max 30 min, elke 2 min.
$qaOk = $false
for ($i = 0; $i -lt 16; $i++) {
    try {
        Invoke-WebRequest -Uri "https://odoo-qa.eeg.be/web/login" -UseBasicParsing -TimeoutSec 20 | Out-Null
        $qaOk = $true; break
    } catch { Start-Sleep -Seconds 120 }
}
if (-not $qaOk) {
    Write-Log "QA niet bereikbaar na 30 min; run uitgesteld tot volgende trigger."
    Show-Toast "Ticket-triage uitgesteld" "Odoo QA niet bereikbaar (VPN?). Volgende poging bij de volgende trigger."
    exit 1
}

$session = [guid]::NewGuid().ToString()
$prompt  = "/ticket-triage $Scope --headless --sessie $session"
Write-Log "Start: $prompt"

Set-Location $workDir
& $claude -p $prompt --session-id $session --settings (Join-Path $base "triage-permissions.json") *>&1 |
    Out-File -FilePath $log -Append -Encoding utf8
$code = $LASTEXITCODE
Write-Log "Einde, exitcode $code"

$rapport = Join-Path $base "rapporten\$today.md"
if ($code -eq 0) {
    if ($Scope -eq "mij") { $today | Out-File -FilePath $marker -Encoding ascii -NoNewline }
    Show-Toast "Ticket-triage klaar" "Rapport: $rapport  (resume: claude --resume $session)"
} else {
    Show-Toast "Ticket-triage mislukt" "Exitcode $code - zie $log"
}
exit $code
