# Requires PowerShell 5.1 or later
param(
    [Parameter(Mandatory=$true)]
    [string]$FolderPath = ".\Texture2D"
)

# Import the System.Drawing assembly for image processing
Add-Type -AssemblyName System.Drawing

# Function to get image dimensions
function Get-ImageDimensions($imagePath) {
    try {
        $image = [System.Drawing.Image]::FromFile($imagePath)
        try {
            return @{
                Width = $image.Width
                Height = $image.Height
            }
        }
        finally {
            $image.Dispose()
        }
    }
    catch {
        Write-Warning "Failed to process image: $imagePath"
        Write-Warning $_.Exception.Message
        return $null
    }
}

# Function to create directory if it doesn't exist
function Ensure-Directory($path) {
    if (-not (Test-Path $path)) {
        New-Item -ItemType Directory -Path $path | Out-Null
        Write-Host "Created directory: $path"
    }
}

# Ensure the main folder exists
if (-not (Test-Path $FolderPath)) {
    Write-Error "Folder not found: $FolderPath"
    exit 1
}

# Create the "Small" directory
$smallDir = Join-Path $FolderPath "Small"
Ensure-Directory $smallDir

# Get all image files (PNG format)
$imageFiles = Get-ChildItem -Path $FolderPath -Filter "*.png" -File

# Initialize counters
$totalFiles = $imageFiles.Count
$processedCount = 0
$errorCount = 0
$movedCount = 0

Write-Host "Found $totalFiles PNG files to process..."

foreach ($file in $imageFiles) {
    $processedCount++
    Write-Progress -Activity "Organizing Images" -Status "$processedCount of $totalFiles" -PercentComplete (($processedCount / $totalFiles) * 100)
    
    # Skip if it's already in a resolution directory
    if ($file.Directory.Name -match "^\d+x\d+$" -or $file.Directory.Name -eq "Small") {
        Write-Host "Skipping already organized file: $($file.Name)"
        continue
    }
    
    $dimensions = Get-ImageDimensions $file.FullName
    if ($null -eq $dimensions) {
        $errorCount++
        continue
    }
    
    # Determine target directory
    $targetDir = if ($dimensions.Width -lt 128 -and $dimensions.Height -lt 128) {
        $smallDir
    } else {
        Join-Path $FolderPath "$($dimensions.Width)x$($dimensions.Height)"
    }
    
    # Create resolution directory if needed
    Ensure-Directory $targetDir
    
    # Move the file
    $targetPath = Join-Path $targetDir $file.Name
    if (Test-Path $targetPath) {
        $basename = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
        $extension = [System.IO.Path]::GetExtension($file.Name)
        $counter = 1
        
        while (Test-Path $targetPath) {
            $newName = "${basename}_${counter}${extension}"
            $targetPath = Join-Path $targetDir $newName
            $counter++
        }
    }
    
    try {
        Move-Item -Path $file.FullName -Destination $targetPath
        $movedCount++
        Write-Host "Moved: $($file.Name) -> $targetPath"
    }
    catch {
        Write-Warning "Failed to move file: $($file.Name)"
        Write-Warning $_.Exception.Message
        $errorCount++
    }
}

Write-Host "`nOrganization complete!"
Write-Host "Total files processed: $totalFiles"
Write-Host "Files moved: $movedCount"
Write-Host "Errors encountered: $errorCount"
