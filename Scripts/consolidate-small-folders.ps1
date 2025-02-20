# Requires PowerShell 5.1 or later
param(
    [Parameter(Mandatory=$true)]
    [string]$FolderPath = ".\Texture2D",
    [int]$MinimumImages = 5
)

# Function to ensure directory exists
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

# Create the Assorted directory
$assortedDir = Join-Path $FolderPath "Assorted"
Ensure-Directory $assortedDir

# Get all subdirectories that match resolution pattern (e.g., "1024x1024")
$resolutionFolders = Get-ChildItem -Path $FolderPath -Directory |
    Where-Object { $_.Name -match '^\d+x\d+$' }

$consolidatedFolders = 0
$movedFiles = 0

foreach ($folder in $resolutionFolders) {
    # Get all PNG files in the current resolution folder
    $files = Get-ChildItem -Path $folder.FullName -Filter "*.png" -File
    $fileCount = $files.Count
    
    Write-Host "`nChecking folder: $($folder.Name) - Contains $fileCount images"
    
    if ($fileCount -lt $MinimumImages) {
        Write-Host "Folder $($folder.Name) has fewer than $MinimumImages images - consolidating..."
        
        foreach ($file in $files) {
            $targetPath = Join-Path $assortedDir $file.Name
            
            # Handle naming conflicts
            if (Test-Path $targetPath) {
                $basename = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
                $extension = [System.IO.Path]::GetExtension($file.Name)
                $counter = 1
                
                while (Test-Path $targetPath) {
                    $newName = "${basename}_${counter}${extension}"
                    $targetPath = Join-Path $assortedDir $newName
                    $counter++
                }
            }
            
            try {
                Move-Item -Path $file.FullName -Destination $targetPath
                $movedFiles++
                Write-Host "Moved: $($file.Name) -> $targetPath"
            }
            catch {
                Write-Warning "Failed to move file: $($file.Name)"
                Write-Warning $_.Exception.Message
                continue
            }
        }
        
        # Delete the now-empty resolution folder
        try {
            Remove-Item -Path $folder.FullName
            $consolidatedFolders++
            Write-Host "Deleted empty folder: $($folder.Name)"
        }
        catch {
            Write-Warning "Failed to delete folder: $($folder.Name)"
            Write-Warning $_.Exception.Message
        }
    }
}

Write-Host "`nConsolidation complete!"
Write-Host "Folders consolidated: $consolidatedFolders"
Write-Host "Files moved: $movedFiles"

# If no files were moved to Assorted, clean it up
if ($movedFiles -eq 0) {
    Remove-Item -Path $assortedDir
    Write-Host "Removed empty Assorted folder as no consolidation was needed"
}
