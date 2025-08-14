# Flowspace (Substrate) Installation Script for Windows
# Supports: Windows 10/11 (PowerShell 5.1+)
# Usage: Invoke-RestMethod https://aka.ms/InstallFlowspace | Invoke-Expression
#   or:  $env:FLOWSPACE_BASE_URL="file:///C:/path/to/releases"; .\install-flowspace.ps1
#
# Environment variables:
#   FLOWSPACE_BASE_URL     - Override download URL (supports file:// for local testing)
#   FLOWSPACE_INSTALL_DIR  - Installation directory (default: $env:LOCALAPPDATA\Programs\Flowspace)
#   FLOWSPACE_VERSION      - Version to install (default: latest)
#   FLOWSPACE_FORCE        - Force reinstall if already exists (default: false)

param(
    [string]$Version = $env:FLOWSPACE_VERSION,
    [string]$InstallDir = $env:FLOWSPACE_INSTALL_DIR,
    [string]$BaseUrl = $env:FLOWSPACE_BASE_URL,
    [switch]$Force = [bool]($env:FLOWSPACE_FORCE -eq "true")
)

# Configuration
$GitHubRepo = "AI-Substrate/flowspace"
$BinaryName = "substrate.exe"
$DefaultInstallDir = "$env:LOCALAPPDATA\Programs\Flowspace"

# Use provided install directory or default
if (-not $InstallDir) {
    $InstallDir = $DefaultInstallDir
}

# Error handling
$ErrorActionPreference = "Stop"

# Logging functions
function Write-Info { 
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Blue 
}

function Write-Warn { 
    param([string]$Message)
    Write-Host "[WARN] $Message" -ForegroundColor Yellow 
}

function Write-Error-Custom { 
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red 
}

function Write-Success { 
    param([string]$Message)
    Write-Host "[SUCCESS] $Message" -ForegroundColor Green 
}

# Welcome message
Write-Info "Flowspace Installation Script"
Write-Info "============================="

# Check PowerShell version
if ($PSVersionTable.PSVersion.Major -lt 3) {
    Write-Error-Custom "PowerShell 3.0 or higher is required"
    exit 1
}

# Detect architecture
function Get-Architecture {
    $arch = $env:PROCESSOR_ARCHITECTURE
    switch ($arch) {
        "AMD64" { return "amd64" }
        "ARM64" { return "arm64" }
        "x86" { return "386" }
        default { 
            Write-Error-Custom "Unsupported architecture: $arch"
            exit 1
        }
    }
}

$Architecture = Get-Architecture
Write-Info "Detected system: windows/$Architecture"
Write-Info "Install directory: $InstallDir"

# Check if already installed and not forcing
$BinaryPath = Join-Path $InstallDir $BinaryName
if ((Test-Path $BinaryPath) -and -not $Force) {
    try {
        $currentVersion = & $BinaryPath --version 2>$null | Select-String -Pattern "v\d+\.\d+\.\d+" | ForEach-Object { $_.Matches[0].Value }
        if ($currentVersion) {
            Write-Info "Flowspace $currentVersion is already installed at $BinaryPath"
            Write-Info "Use -Force to reinstall or set FLOWSPACE_FORCE=true"
            exit 0
        }
    } catch {
        Write-Warn "Could not determine current version, proceeding with installation"
    }
}

# Get latest version if not specified
function Get-LatestVersion {
    try {
        $apiUrl = "https://api.github.com/repos/$GitHubRepo/releases/latest"
        Write-Info "Fetching latest version from GitHub API..."
        
        $response = Invoke-RestMethod -Uri $apiUrl -UseBasicParsing
        return $response.tag_name
    } catch {
        Write-Error-Custom "Failed to fetch latest version from GitHub API"
        Write-Error-Custom "Please specify a version using FLOWSPACE_VERSION environment variable"
        exit 1
    }
}

if (-not $Version -or $Version -eq "latest") {
    $Version = Get-LatestVersion
}

Write-Info "Installing version: $Version"

# Download and install
function Install-Binary {
    param(
        [string]$Version,
        [string]$Architecture
    )
    
    # Remove 'v' prefix if present
    $CleanVersion = $Version -replace '^v', ''
    
    $ArchiveName = "substrate-v$CleanVersion-windows-$Architecture.zip"
    $BinaryNameInArchive = "substrate-windows-$Architecture.exe"
    
    # Determine download URL
    if ($BaseUrl) {
        $DownloadUrl = "$BaseUrl/$ArchiveName"
    } else {
        $DownloadUrl = "https://github.com/$GitHubRepo/releases/download/$Version/$ArchiveName"
    }
    
    $TempDir = [System.IO.Path]::GetTempPath()
    $ArchivePath = Join-Path $TempDir $ArchiveName
    
    Write-Info "Downloading $ArchiveName..."
    Write-Info "URL: $DownloadUrl"
    
    try {
        # Handle file:// URLs differently
        if ($DownloadUrl.StartsWith("file://")) {
            $FilePath = $DownloadUrl -replace "^file://", ""
            # Convert forward slashes to backslashes for Windows
            $FilePath = $FilePath -replace "/", "\"
            
            if (Test-Path $FilePath) {
                Write-Info "Copying local file: $FilePath"
                Copy-Item $FilePath $ArchivePath
            } else {
                Write-Error-Custom "Local file not found: $FilePath"
                exit 1
            }
        } else {
            # Download from HTTP/HTTPS
            Invoke-WebRequest -Uri $DownloadUrl -OutFile $ArchivePath -UseBasicParsing
        }
    } catch {
        Write-Error-Custom "Failed to download $ArchiveName"
        Write-Error-Custom "Please check if version $Version exists for windows/$Architecture"
        exit 1
    }
    
    # Verify download
    if (-not (Test-Path $ArchivePath) -or (Get-Item $ArchivePath).Length -eq 0) {
        Write-Error-Custom "Downloaded file is empty or does not exist"
        exit 1
    }
    
    Write-Info "Extracting archive..."
    
    # Create temporary extraction directory
    $ExtractDir = Join-Path $TempDir "substrate-extract-$(Get-Random)"
    
    try {
        # Extract the zip file
        Expand-Archive -Path $ArchivePath -DestinationPath $ExtractDir -Force
        
        # Find the binary in the extracted files
        $ExtractedBinary = Join-Path $ExtractDir $BinaryNameInArchive
        if (-not (Test-Path $ExtractedBinary)) {
            Write-Error-Custom "Binary $BinaryNameInArchive not found in archive"
            exit 1
        }
        
        # Create install directory
        if (-not (Test-Path $InstallDir)) {
            Write-Info "Creating install directory: $InstallDir"
            New-Item -Path $InstallDir -ItemType Directory -Force | Out-Null
        }
        
        # Install the binary
        Write-Info "Installing binary to $BinaryPath..."
        Copy-Item $ExtractedBinary $BinaryPath -Force
        
        # Verify installation
        if (Test-Path $BinaryPath) {
            Write-Success "Flowspace installed successfully!"
            
            # Test the binary
            try {
                $versionOutput = & $BinaryPath --version 2>$null
                Write-Success "Installation verified: $versionOutput"
            } catch {
                Write-Success "Installation verified: Binary is executable"
            }
            
            # Check if install directory is in PATH
            $pathDirs = $env:PATH -split ";"
            $isInPath = $pathDirs -contains $InstallDir
            
            if (-not $isInPath) {
                Write-Info ""
                Write-Warn "Installation directory is not in your PATH"
                Write-Info "To add it to your PATH, run:"
                Write-Info "  [Environment]::SetEnvironmentVariable('PATH', `$env:PATH + ';$InstallDir', 'User')"
                Write-Info ""
                Write-Info "Or you can run the binary directly:"
                Write-Info "  $BinaryPath --help"
            } else {
                Write-Info "You can now run: substrate --help"
            }
            
        } else {
            Write-Error-Custom "Failed to install binary to $BinaryPath"
            exit 1
        }
        
    } finally {
        # Cleanup
        if (Test-Path $ArchivePath) {
            Remove-Item $ArchivePath -Force
        }
        if (Test-Path $ExtractDir) {
            Remove-Item $ExtractDir -Recurse -Force
        }
    }
}

# Run the installation
try {
    Install-Binary -Version $Version -Architecture $Architecture
    Write-Success "Flowspace installation completed!"
} catch {
    Write-Error-Custom "Installation failed: $_"
    exit 1
}
