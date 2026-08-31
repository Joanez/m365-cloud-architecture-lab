# Uninstall-TeamsBackgrounds.ps1

$MarkerFolder = Join-Path $env:LOCALAPPDATA "Sonepar\TeamsBackgrounds"
$ManifestFile = Join-Path $MarkerFolder "manifest.json"
$TeamsBackgroundPath = Join-Path $env:LOCALAPPDATA "Packages\MSTeams_8wekyb3d8bbwe\LocalCache\Microsoft\MSTeams\Backgrounds\Uploads"

try {
    if (Test-Path $ManifestFile) {
        $Manifest = Get-Content -Path $ManifestFile -Raw | ConvertFrom-Json

        foreach ($Item in $Manifest) {
            $BackgroundFile = Join-Path $TeamsBackgroundPath $Item.BackgroundFile
            $ThumbnailFile = Join-Path $TeamsBackgroundPath $Item.ThumbnailFile

            if (Test-Path $BackgroundFile) {
                Remove-Item -Path $BackgroundFile -Force -ErrorAction SilentlyContinue
            }

            if (Test-Path $ThumbnailFile) {
                Remove-Item -Path $ThumbnailFile -Force -ErrorAction SilentlyContinue
            }
        }
    }

    if (Test-Path $MarkerFolder) {
        Remove-Item -Path $MarkerFolder -Recurse -Force -ErrorAction SilentlyContinue
    }

    Write-Output "Teams backgrounds removed successfully."
    exit 0
}
catch {
    Write-Error "Failed to uninstall Teams backgrounds. Error: $($_.Exception.Message)"
    exit 1
}
