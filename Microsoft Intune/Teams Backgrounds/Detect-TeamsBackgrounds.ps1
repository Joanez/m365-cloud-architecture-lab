# Detect-TeamsBackgrounds.ps1

$ExpectedVersion = "1.4.0"

$MarkerFile = Join-Path `
    $env:LOCALAPPDATA `
    "TeamsBackgrounds\version.txt"

$ManifestFile = Join-Path `
    $env:LOCALAPPDATA `
    "TeamsBackgrounds\manifest.json"

$TeamsBackgroundPath = Join-Path `
    $env:LOCALAPPDATA `
    "Packages\MSTeams_8wekyb3d8bbwe\LocalCache\Microsoft\MSTeams\Backgrounds\Uploads"

try {
    if (-not (Test-Path $MarkerFile)) {
        exit 1
    }

    if (-not (Test-Path $ManifestFile)) {
        exit 1
    }

    $InstalledVersion = Get-Content `
        -Path $MarkerFile `
        -ErrorAction Stop

    if ($InstalledVersion -ne $ExpectedVersion) {
        exit 1
    }

    $Manifest = Get-Content `
        -Path $ManifestFile `
        -Raw |
        ConvertFrom-Json

    foreach ($Item in $Manifest) {
        $BackgroundFile = Join-Path `
            $TeamsBackgroundPath `
            $Item.BackgroundFile

        $ThumbnailFile = Join-Path `
            $TeamsBackgroundPath `
            $Item.ThumbnailFile

        if (-not (Test-Path $BackgroundFile)) {
            exit 1
        }

        if (-not (Test-Path $ThumbnailFile)) {
            exit 1
        }
    }

    Write-Output "Detected"
    exit 0
}
catch {
    exit 1
}
