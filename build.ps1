param(
    [switch]$ForceInstall
)

$ErrorActionPreference = "Stop"
$repo = $PSScriptRoot
$tools = Join-Path $env:TEMP "iic2531-marp"
$marp = Join-Path $tools "node_modules\.bin\marp.cmd"

if ($ForceInstall -or -not (Test-Path $marp)) {
    New-Item -ItemType Directory -Force -Path $tools | Out-Null
    if (-not (Test-Path (Join-Path $tools "package.json"))) {
        Push-Location $tools
        npm init -y | Out-Null
        Pop-Location
    }
    Push-Location $tools
    npm install --no-fund --no-audit "@marp-team/marp-cli@4.5.1"
    Pop-Location
}

$chromeCandidates = @(
    "C:\Program Files\Google\Chrome\Application\chrome.exe",
    "C:\Program Files (x86)\Google\Chrome\Application\chrome.exe",
    "C:\Program Files\Microsoft\Edge\Application\msedge.exe",
    "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
)
$chrome = $chromeCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if ($chrome) {
    $env:CHROME_PATH = $chrome
}

Get-ChildItem $repo -Directory -Filter "Clase*" |
    Sort-Object Name |
    ForEach-Object {
        $classDir = $_.FullName
        $markdown = Get-ChildItem $classDir -Filter "*.md" | Select-Object -First 1
        if (-not $markdown) {
            return
        }

        $pdf = [System.IO.Path]::ChangeExtension($markdown.FullName, ".pdf")
        Write-Host "Renderizando $($markdown.Name)..." -ForegroundColor Cyan
        & $marp $markdown.FullName --pdf --allow-local-files --pdf-outlines --no-stdin -o $pdf
        if ($LASTEXITCODE -ne 0) {
            throw "Marp falló al renderizar $($markdown.FullName)"
        }
    }

Write-Host "Listo: PDFs regenerados en $repo" -ForegroundColor Green
