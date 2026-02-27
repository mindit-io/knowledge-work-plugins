# Package individual plugins for upload as Organization skills in Cowork.
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File scripts/package.ps1 <plugin>
#   powershell -ExecutionPolicy Bypass -File scripts/package.ps1 all
#
# Examples:
#   powershell -ExecutionPolicy Bypass -File scripts/package.ps1 sales
#   powershell -ExecutionPolicy Bypass -File scripts/package.ps1 partner-built/slack
#   powershell -ExecutionPolicy Bypass -File scripts/package.ps1 all
#
# Note: Uses .NET ZipFile API instead of Compress-Archive to ensure
# forward-slash path separators (ZIP spec §4.4.17.1). Compress-Archive
# on Windows PowerShell writes backslashes, which Cowork rejects as
# "zip file contains path with invalid characters".

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$repoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$distDir  = Join-Path $repoRoot "dist"
if (-not (Test-Path $distDir)) { New-Item -ItemType Directory -Path $distDir | Out-Null }

function Package-Plugin {
    param([string]$PluginDir)

    $fullPath = Join-Path $repoRoot $PluginDir
    $cpDir    = Join-Path $fullPath ".claude-plugin"

    if (-not (Test-Path $cpDir)) {
        Write-Host "SKIP  $PluginDir (no .claude-plugin/ directory)"
        return
    }

    $zipName = ($PluginDir -replace '[/\\]', '-') + ".zip"
    $outFile = Join-Path $distDir $zipName

    if (Test-Path $outFile) { Remove-Item $outFile }

    $exclude = @(".git", "node_modules", ".env")

    # Create zip using .NET API with forward-slash entry names
    $zipStream = [System.IO.File]::Create($outFile)
    $archive   = New-Object System.IO.Compression.ZipArchive($zipStream, [System.IO.Compression.ZipArchiveMode]::Create)

    $files = Get-ChildItem -Path $fullPath -Recurse -File
    foreach ($file in $files) {
        $relativePath = $file.FullName.Substring($fullPath.Length + 1)

        # Skip excluded directories
        $skip = $false
        foreach ($ex in $exclude) {
            if ($relativePath -like "$ex\*" -or $relativePath -like "$ex/*" -or $relativePath -eq $ex) {
                $skip = $true
                break
            }
        }
        if ($relativePath -like "*.zip") { $skip = $true }
        if ($skip) { continue }

        # Normalize to forward slashes (ZIP spec requirement)
        $entryName = $relativePath -replace '\\', '/'

        $entry = $archive.CreateEntry($entryName, [System.IO.Compression.CompressionLevel]::Optimal)
        $entryStream = $entry.Open()
        $fileStream  = [System.IO.File]::OpenRead($file.FullName)
        $fileStream.CopyTo($entryStream)
        $fileStream.Close()
        $entryStream.Close()
    }

    $archive.Dispose()
    $zipStream.Close()

    $size = [math]::Round((Get-Item $outFile).Length / 1KB)
    Write-Host "OK    $zipName (${size} KB)"
}

function Discover-Plugins {
    $plugins = @()
    foreach ($d in Get-ChildItem -Path $repoRoot -Directory) {
        if ($d.Name -in @("scripts", "dist", ".git")) { continue }
        if (Test-Path (Join-Path $d.FullName ".claude-plugin")) {
            $plugins += $d.Name
        }
        if ($d.Name -eq "partner-built") {
            foreach ($sub in Get-ChildItem -Path $d.FullName -Directory) {
                if (Test-Path (Join-Path $sub.FullName ".claude-plugin")) {
                    $plugins += "partner-built/$($sub.Name)"
                }
            }
        }
    }
    return $plugins
}

# --- Main ---

if ($args.Count -eq 0) {
    Write-Host "Usage: powershell -ExecutionPolicy Bypass -File scripts/package.ps1 <plugin|all>"
    Write-Host ""
    Write-Host "Available plugins:"
    Discover-Plugins | ForEach-Object { Write-Host "  $_" }
    exit 1
}

$target = $args[0]

if ($target -eq "all") {
    Write-Host "Packaging all plugins into dist/ ..."
    foreach ($plugin in Discover-Plugins) {
        Package-Plugin -PluginDir $plugin
    }
    Write-Host ""
    Write-Host "Done. Zips are in $distDir\"
} else {
    $targetPath = Join-Path $repoRoot $target
    if (-not (Test-Path $targetPath)) {
        Write-Host "Error: directory '$target' not found"
        exit 1
    }
    Package-Plugin -PluginDir $target
}
