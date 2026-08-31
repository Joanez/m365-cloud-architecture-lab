# Install-TeamsBackgrounds.ps1
# Deploys corporate Teams backgrounds for New Teams.
# The Teams Uploads folder is fully managed by this application.
# Every installation or update clears the folder before installing
# the current background images and generated thumbnails.

$AppName = "SoneparTeamsBackgrounds"
$AppVersion = "1.4.0"

$SourceFolder = Join-Path `
    -Path $PSScriptRoot `
    -ChildPath "Backgrounds"

$TeamsBackgroundPath = Join-Path `
    -Path $env:LOCALAPPDATA `
    -ChildPath "Packages\MSTeams_8wekyb3d8bbwe\LocalCache\Microsoft\MSTeams\Backgrounds\Uploads"

$MarkerFolder = Join-Path `
    -Path $env:LOCALAPPDATA `
    -ChildPath "Sonepar\TeamsBackgrounds"

$MarkerFile = Join-Path `
    -Path $MarkerFolder `
    -ChildPath "version.txt"

$ManifestFile = Join-Path `
    -Path $MarkerFolder `
    -ChildPath "manifest.json"

function New-StableGuidFromFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )

    $SHA1 = [System.Security.Cryptography.SHA1]::Create()
    $Stream = [System.IO.File]::OpenRead($FilePath)

    try {
        $HashBytes = $SHA1.ComputeHash($Stream)
    }
    finally {
        $Stream.Dispose()
        $SHA1.Dispose()
    }

    $HashString = [System.BitConverter]::ToString($HashBytes)
    $HashString = $HashString.Replace("-", "")
    $GuidString = $HashString.Substring(0, 32)

    return [System.Guid]::ParseExact(
        $GuidString,
        "N"
    ).ToString()
}

function New-TeamsThumbnail {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourceImage,

        [Parameter(Mandatory = $true)]
        [string]$DestinationImage
    )

    Add-Type -AssemblyName System.Drawing

    $ThumbnailWidth = 202
    $ThumbnailHeight = 114

    $Source = $null
    $Bitmap = $null
    $Graphics = $null

    try {
        $Source = [System.Drawing.Image]::FromFile($SourceImage)

        $Bitmap = New-Object System.Drawing.Bitmap `
            -ArgumentList $ThumbnailWidth, $ThumbnailHeight

        $Bitmap.SetResolution(
            $Source.HorizontalResolution,
            $Source.VerticalResolution
        )

        $Graphics = [System.Drawing.Graphics]::FromImage($Bitmap)

        $Graphics.CompositingMode = `
            [System.Drawing.Drawing2D.CompositingMode]::SourceCopy

        $Graphics.CompositingQuality = `
            [System.Drawing.Drawing2D.CompositingQuality]::HighQuality

        $Graphics.InterpolationMode = `
            [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic

        $Graphics.SmoothingMode = `
            [System.Drawing.Drawing2D.SmoothingMode]::HighQuality

        $Graphics.PixelOffsetMode = `
            [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality

        $DestinationRectangle = New-Object System.Drawing.Rectangle `
            -ArgumentList 0, 0, $ThumbnailWidth, $ThumbnailHeight

        $Graphics.DrawImage(
            $Source,
            $DestinationRectangle,
            0,
            0,
            $Source.Width,
            $Source.Height,
            [System.Drawing.GraphicsUnit]::Pixel
        )

        $Extension = [System.IO.Path]::GetExtension(
            $DestinationImage
        ).ToLowerInvariant()

        switch ($Extension) {
            ".png" {
                $Bitmap.Save(
                    $DestinationImage,
                    [System.Drawing.Imaging.ImageFormat]::Png
                )
            }

            ".jpg" {
                $Bitmap.Save(
                    $DestinationImage,
                    [System.Drawing.Imaging.ImageFormat]::Jpeg
                )
            }

            ".jpeg" {
                $Bitmap.Save(
                    $DestinationImage,
                    [System.Drawing.Imaging.ImageFormat]::Jpeg
                )
            }

            default {
                throw "Unsupported thumbnail extension: $Extension"
            }
        }
    }
    finally {
        if ($Graphics) {
            $Graphics.Dispose()
        }

        if ($Bitmap) {
            $Bitmap.Dispose()
        }

        if ($Source) {
            $Source.Dispose()
        }
    }
}

function Clear-TeamsBackgroundFolder {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$BackgroundPath
    )

    if (-not (Test-Path -LiteralPath $BackgroundPath -PathType Container)) {
        Write-Output "Teams background folder does not exist. It will be created."
        return
    }

    $ExistingItems = @(
        Get-ChildItem `
            -LiteralPath $BackgroundPath `
            -Force `
            -ErrorAction Stop
    )

    if ($ExistingItems.Count -eq 0) {
        Write-Output "Teams background folder is already empty."
        return
    }

    foreach ($Item in $ExistingItems) {
        Remove-Item `
            -LiteralPath $Item.FullName `
            -Recurse `
            -Force `
            -ErrorAction Stop

        Write-Output "Removed existing item: $($Item.Name)"
    }

    Write-Output "Existing Teams backgrounds and thumbnails removed."
}

try {
    Write-Output "Starting installation of $AppName version $AppVersion."

    if (-not (Test-Path -LiteralPath $SourceFolder -PathType Container)) {
        throw "Source folder not found: $SourceFolder"
    }

    $SupportedExtensions = @(
        ".jpg"
        ".jpeg"
        ".png"
    )

    $BackgroundFiles = @(
        Get-ChildItem `
            -LiteralPath $SourceFolder `
            -File `
            -ErrorAction Stop |
        Where-Object {
            $SupportedExtensions -contains $_.Extension.ToLowerInvariant()
        }
    )

    if ($BackgroundFiles.Count -eq 0) {
        throw "No supported background files found in: $SourceFolder"
    }

    New-Item `
        -Path $TeamsBackgroundPath `
        -ItemType Directory `
        -Force `
        -ErrorAction Stop |
    Out-Null

    New-Item `
        -Path $MarkerFolder `
        -ItemType Directory `
        -Force `
        -ErrorAction Stop |
    Out-Null

    # This application fully manages the Teams Uploads folder.
    # Remove everything before installing the current background set.
    Clear-TeamsBackgroundFolder `
        -BackgroundPath $TeamsBackgroundPath

    $Manifest = @()

    foreach ($File in $BackgroundFiles) {
        $Guid = New-StableGuidFromFile `
            -FilePath $File.FullName

        $Extension = $File.Extension.ToLowerInvariant()

        $DestinationBackground = Join-Path `
            -Path $TeamsBackgroundPath `
            -ChildPath "$Guid$Extension"

        $DestinationThumbnail = Join-Path `
            -Path $TeamsBackgroundPath `
            -ChildPath "$Guid`_thumb$Extension"

        Write-Output "Processing background: $($File.Name)"

        # Copy the original background without resizing,
        # converting, or recompressing it.
        Copy-Item `
            -LiteralPath $File.FullName `
            -Destination $DestinationBackground `
            -Force `
            -ErrorAction Stop

        # Generate the corresponding 202 x 114 thumbnail.
        New-TeamsThumbnail `
            -SourceImage $File.FullName `
            -DestinationImage $DestinationThumbnail

        if (-not (
            Test-Path `
                -LiteralPath $DestinationBackground `
                -PathType Leaf
        )) {
            throw "Background file was not created: $DestinationBackground"
        }

        if (-not (
            Test-Path `
                -LiteralPath $DestinationThumbnail `
                -PathType Leaf
        )) {
            throw "Thumbnail file was not created: $DestinationThumbnail"
        }

        # Confirm the copied background remains identical to the source.
        $SourceHash = Get-FileHash `
            -LiteralPath $File.FullName `
            -Algorithm SHA256 `
            -ErrorAction Stop

        $DestinationHash = Get-FileHash `
            -LiteralPath $DestinationBackground `
            -Algorithm SHA256 `
            -ErrorAction Stop

        if ($SourceHash.Hash -ne $DestinationHash.Hash) {
            throw "Hash validation failed for background: $($File.Name)"
        }

        $BackgroundItem = Get-Item `
            -LiteralPath $DestinationBackground `
            -ErrorAction Stop

        $ThumbnailItem = Get-Item `
            -LiteralPath $DestinationThumbnail `
            -ErrorAction Stop

        if ($BackgroundItem.Length -eq 0) {
            throw "Background file is empty: $DestinationBackground"
        }

        if ($ThumbnailItem.Length -eq 0) {
            throw "Thumbnail file is empty: $DestinationThumbnail"
        }

        $Manifest += [PSCustomObject]@{
            SourceFile          = $File.Name
            Guid                = $Guid
            BackgroundFile      = $BackgroundItem.Name
            BackgroundSizeBytes = $BackgroundItem.Length
            BackgroundHash      = $DestinationHash.Hash
            ThumbnailFile       = $ThumbnailItem.Name
            ThumbnailSizeBytes  = $ThumbnailItem.Length
            ThumbnailWidth      = 202
            ThumbnailHeight     = 114
            Version             = $AppVersion
        }

        Write-Output "Installed background: $($BackgroundItem.Name)"
        Write-Output "Generated thumbnail: $($ThumbnailItem.Name)"
        Write-Output "Background hash validated successfully."
    }

    $Manifest |
        ConvertTo-Json -Depth 4 |
        Set-Content `
            -LiteralPath $ManifestFile `
            -Encoding UTF8 `
            -Force `
            -ErrorAction Stop

    $AppVersion |
        Set-Content `
            -LiteralPath $MarkerFile `
            -Encoding UTF8 `
            -Force `
            -ErrorAction Stop

    Write-Output "$AppName version $AppVersion installed successfully."
    Write-Output "Installed backgrounds: $($BackgroundFiles.Count)"
    Write-Output "Teams must be restarted before testing the new backgrounds."

    exit 0
}
catch {
    Write-Error "Failed to install Teams backgrounds. Error: $($_.Exception.Message)"
    exit 1
}
