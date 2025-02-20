# Requires PowerShell 5.1 or later
param(
    [Parameter(Mandatory=$true)]
    [string]$FolderPath = ".\Texture2D"
)

# Function to calculate file hash
function Get-FileHash256([string]$filePath) {
    $fileStream = [System.IO.File]::OpenRead($filePath)
    try {
        $hasher = [System.Security.Cryptography.SHA256]::Create()
        $hash = [System.BitConverter]::ToString($hasher.ComputeHash($fileStream))
        return $hash.Replace("-", "")
    }
    finally {
        $fileStream.Close()
        $hasher.Dispose()
    }
}

# Ensure the folder exists
if (-not (Test-Path $FolderPath)) {
    Write-Error "Folder not found: $FolderPath"
    exit 1
}

# Initialize tracking variables
$hashMapping = @{}  # Hash to first filename mapping
$fileMapping = @{}  # Original filename to preserved filename mapping
$processedCount = 0
$deletedCount = 0

# Get all PNG files
$pngFiles = Get-ChildItem -Path $FolderPath -Filter "*.png" -File

# Total files for progress
$totalFiles = $pngFiles.Count
Write-Host "Found $totalFiles PNG files to process..."

foreach ($file in $pngFiles) {
    $processedCount++
    Write-Progress -Activity "Processing Images" -Status "$processedCount of $totalFiles" -PercentComplete (($processedCount / $totalFiles) * 100)
    
    $hash = Get-FileHash256 $file.FullName
    $relativePath = $file.FullName.Substring($FolderPath.Length + 1)
    
    if ($hashMapping.ContainsKey($hash)) {
        # Duplicate found
        $fileMapping[$relativePath] = $hashMapping[$hash]
        Remove-Item $file.FullName
        $deletedCount++
        Write-Host "Duplicate removed: $relativePath -> $($hashMapping[$hash])"
    }
    else {
        # New unique file
        $hashMapping[$hash] = $relativePath
        $fileMapping[$relativePath] = $relativePath
    }
}

# Save the mapping to JSON
$jsonPath = Join-Path $FolderPath "image_mapping.json"
$fileMapping | ConvertTo-Json | Out-File $jsonPath -Encoding UTF8

Write-Host "`nProcessing complete!"
Write-Host "Total files processed: $totalFiles"
Write-Host "Duplicates removed: $deletedCount"
Write-Host "Mapping saved to: $jsonPath"
