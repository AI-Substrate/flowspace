# Flowspace Installation Script for Windows
# Supports: Windows 10/11 (PowerShell 5.1+)
# Usage: Invoke-RestMethod https://aka.ms/InstallFlowspace | Invoke-Expression
#   or:  $env:FLOWSPACE_PRE_RELEASE="true"; Invoke-RestMethod https://aka.ms/InstallFlowspace | Invoke-Expression
#   or:  $env:FLOWSPACE_BASE_URL="file:///C:/path/to/releases"; .\install-flowspace.ps1
#
# Command line options:
#   -Version VERSION        Install specific version (default: latest)
#   -InstallDir DIR         Installation directory (default: $env:LOCALAPPDATA\Programs\Flowspace)
#   -BaseUrl URL            Override download URL (supports file://)
#   -NoGcm                  Disable Git Credential Manager authentication
#   -PreRelease             Include pre-release versions when fetching latest
#   -Force                  Force reinstall if already exists
#   -Help                   Show help message
#
# Environment variables:
#   FLOWSPACE_BASE_URL      Override download URL (supports file:// for local testing)
#   FLOWSPACE_INSTALL_DIR   Installation directory (default: $env:LOCALAPPDATA\Programs\Flowspace)
#   FLOWSPACE_VERSION       Version to install (default: latest)
#   FLOWSPACE_FORCE         Force reinstall if already exists (default: false)
#   FLOWSPACE_USE_GCM_AUTH  Use Git Credential Manager for GitHub auth (default: true)
#   FLOWSPACE_PRE_RELEASE   Include pre-release versions (default: false)

[CmdletBinding()]
param(
    [string]$Version = $env:FLOWSPACE_VERSION,
    [string]$InstallDir = $env:FLOWSPACE_INSTALL_DIR,
    [string]$BaseUrl = $env:FLOWSPACE_BASE_URL,
    [switch]$NoGcm = $false,
    [switch]$PreRelease = [bool]($env:FLOWSPACE_PRE_RELEASE -eq "true"),
    [switch]$Force = [bool]($env:FLOWSPACE_FORCE -eq "true"),
    [switch]$Help = $false
)

# Configuration
$GitHubRepo = "AI-Substrate/flowspace"
$BinaryName = "flowspace.exe"
$DefaultInstallDir = "$env:LOCALAPPDATA\Programs\Flowspace"

# Handle help request
if ($Help) {
    Write-Host @"
Flowspace Installation Script for Windows

Usage: .\install-flowspace.ps1 [OPTIONS]

Options:
    -Version VERSION        Install specific version (default: latest)
    -InstallDir DIR         Installation directory (default: $DefaultInstallDir)
    -BaseUrl URL            Override download URL (supports file://)
    -NoGcm                  Disable Git Credential Manager authentication
    -PreRelease             Include pre-release versions when fetching latest
    -Force                  Force reinstall if already exists
    -Help                   Show this help message

Environment variables:
    FLOWSPACE_BASE_URL      Override download URL
    FLOWSPACE_INSTALL_DIR   Installation directory
    FLOWSPACE_VERSION       Version to install
    FLOWSPACE_FORCE         Force reinstall if already exists
    FLOWSPACE_USE_GCM_AUTH  Use Git Credential Manager (true/false)
    FLOWSPACE_PRE_RELEASE   Include pre-release versions (true/false)

Examples:
    .\install-flowspace.ps1                              # Install latest version
    .\install-flowspace.ps1 -Version v1.0.0             # Install specific version
    .\install-flowspace.ps1 -InstallDir C:\Tools        # Install to custom directory
    .\install-flowspace.ps1 -PreRelease                 # Install latest including pre-releases
    .\install-flowspace.ps1 -BaseUrl file:///C:/path    # Install from local files

Quick install examples:
    Invoke-RestMethod https://aka.ms/InstallFlowspace | Invoke-Expression
    `$env:FLOWSPACE_PRE_RELEASE="true"; Invoke-RestMethod https://aka.ms/InstallFlowspace | Invoke-Expression

"@
    exit 0
}

# Determine GCM usage
$UseGcmAuth = if ($NoGcm) { $false } elseif ($env:FLOWSPACE_USE_GCM_AUTH -eq "false") { $false } else { $true }

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

# Docker availability check
function Test-DockerAvailability {
    # Check if docker command is available
    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
        return $false
    }
    
    try {
        # Check if Docker daemon is responding
        $null = docker version --format '{{.Server.Version}}' 2>$null
        return $true
    } catch {
        return $false
    }
}

function Test-DockerEnvironment {
    Write-Info "Validating Docker environment..."
    
    # Check if docker command is available
    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
        Write-Error-Custom "Docker is not installed"
        Write-Error-Custom "Flowspace requires Docker to function properly"
        Write-Error-Custom ""
        Write-Error-Custom "Please install Docker Desktop from https://docker.com/products/docker-desktop"
        Write-Error-Custom "After installing Docker Desktop, restart your terminal and try again."
        exit 1
    }
    
    # Check if Docker daemon is running
    try {
        $dockerVersion = docker version --format '{{.Server.Version}}' 2>$null
        if (-not $dockerVersion) {
            Write-Error-Custom "Docker is installed but not running"
            Write-Error-Custom "Please start Docker Desktop and try again"
            exit 1
        }
        
        Write-Success "Docker environment validated successfully (version: $dockerVersion)"
    } catch {
        Write-Error-Custom "Docker is installed but not accessible"
        Write-Error-Custom "Please ensure Docker Desktop is running and try again"
        Write-Error-Custom "You may need to restart your terminal after starting Docker"
        exit 1
    }
}

# Git Credential Manager integration
function Get-GitHubToken {
    if (-not $UseGcmAuth) {
        return $null
    }
    
    try {
        if (Get-Command git -ErrorAction SilentlyContinue) {
            $credential = "protocol=https`nhost=github.com`n" | git credential fill 2>$null
            if ($credential -match "password=(.+)") {
                return $matches[1]
            }
        }
    } catch {
        # Ignore errors and return null
    }
    
    return $null
}

# Repository visibility detection
function Get-RepositoryVisibility {
    param([string]$Repo)
    
    try {
        # Try public API first
        $response = Invoke-RestMethod -Uri "https://api.github.com/repos/$Repo" -UseBasicParsing -ErrorAction SilentlyContinue
        return "public"
    } catch {
        # Try with authentication if available
        $token = Get-GitHubToken
        if ($token) {
            try {
                $headers = @{ Authorization = "token $token" }
                $response = Invoke-RestMethod -Uri "https://api.github.com/repos/$Repo" -Headers $headers -UseBasicParsing -ErrorAction SilentlyContinue
                return "private"
            } catch {
                # Could not access
            }
        }
        return "unknown"
    }
}

# Make authenticated API request
function Invoke-ApiRequest {
    param(
        [string]$Url,
        [hashtable]$Headers = @{}
    )
    
    $token = Get-GitHubToken
    if ($token) {
        $Headers["Authorization"] = "token $token"
        Write-Info "Using authenticated API request"
    }
    
    try {
        return Invoke-RestMethod -Uri $Url -Headers $Headers -UseBasicParsing
    } catch {
        Write-Warn "API request failed for: $Url"
        throw
    }
}

# Checksum verification
function Test-FileChecksum {
    param(
        [string]$FilePath,
        [string]$ExpectedChecksum
    )
    
    if (-not $ExpectedChecksum) {
        Write-Warn "No checksum provided - skipping verification"
        return $true
    }
    
    Write-Info "Verifying file integrity..."
    
    try {
        $hash = Get-FileHash -Path $FilePath -Algorithm SHA256
        $actualChecksum = $hash.Hash.ToLower()
        $expectedLower = $ExpectedChecksum.ToLower()
        
        if ($actualChecksum -eq $expectedLower) {
            Write-Success "Checksum verification passed"
            return $true
        } else {
            Write-Error-Custom "Checksum verification failed!"
            Write-Error-Custom "Expected: $expectedLower"
            Write-Error-Custom "Actual:   $actualChecksum"
            Write-Error-Custom "This could indicate a corrupted download or security issue"
            return $false
        }
    } catch {
        Write-Warn "Checksum verification failed: $_"
        return $false
    }
}

# Get checksum for release asset
function Get-ReleaseChecksum {
    param(
        [string]$Version,
        [string]$ArchiveName
    )
    
    Write-Info "Fetching asset checksum from GitHub API..."
    
    $apiUrl = "https://api.github.com/repos/$GitHubRepo/releases/tags/$Version"
    $checksum = ""
    
    try {
        $releaseData = Invoke-ApiRequest -Url $apiUrl
        
        # Look for the asset and extract its digest/checksum
        foreach ($asset in $releaseData.assets) {
            if ($asset.name -eq $ArchiveName) {
                if ($asset.digest) {
                    $checksum = $asset.digest -replace '^sha256:', ''
                }
                break
            }
        }
        
        # Fallback to checksums.txt if no digest available
        if (-not $checksum -and -not $BaseUrl) {
            Write-Warn "No digest available from GitHub API, trying checksums.txt fallback..."
            $checksumsUrl = "https://github.com/$GitHubRepo/releases/download/$Version/checksums.txt"
            
            try {
                $token = Get-GitHubToken
                $headers = @{}
                if ($token) {
                    $headers["Authorization"] = "token $token"
                }
                
                $checksumsContent = Invoke-RestMethod -Uri $checksumsUrl -Headers $headers -UseBasicParsing
                $lines = $checksumsContent -split "`n"
                foreach ($line in $lines) {
                    if ($line -match "^([a-fA-F0-9]+)\s+$([regex]::Escape($ArchiveName))$") {
                        $checksum = $matches[1]
                        break
                    }
                }
            } catch {
                Write-Warn "Could not fetch checksums.txt"
            }
        } elseif ($BaseUrl) {
            # Handle custom BASE_URL
            $checksumsUrl = "$BaseUrl/checksums.txt"
            if ($checksumsUrl.StartsWith("file://")) {
                $filePath = $checksumsUrl -replace "^file://", "" -replace "/", "\"
                if (Test-Path $filePath) {
                    $checksumsContent = Get-Content $filePath -Raw
                    $lines = $checksumsContent -split "`n"
                    foreach ($line in $lines) {
                        if ($line -match "^([a-fA-F0-9]+)\s+$([regex]::Escape($ArchiveName))$") {
                            $checksum = $matches[1]
                            break
                        }
                    }
                }
            } else {
                try {
                    $checksumsContent = Invoke-RestMethod -Uri $checksumsUrl -UseBasicParsing
                    $lines = $checksumsContent -split "`n"
                    foreach ($line in $lines) {
                        if ($line -match "^([a-fA-F0-9]+)\s+$([regex]::Escape($ArchiveName))$") {
                            $checksum = $matches[1]
                            break
                        }
                    }
                } catch {
                    Write-Warn "Could not fetch checksums from $checksumsUrl"
                }
            }
        }
    } catch {
        Write-Warn "Could not fetch checksum information"
    }
    
    return $checksum
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

# Validate Docker environment
Test-DockerEnvironment

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
        # Choose API endpoint based on pre-release preference
        if ($PreRelease) {
            $apiUrl = "https://api.github.com/repos/$GitHubRepo/releases"
            Write-Info "Fetching latest version (including pre-releases) from GitHub..."
        } else {
            $apiUrl = "https://api.github.com/repos/$GitHubRepo/releases/latest"
            Write-Info "Fetching latest version from GitHub..."
        }
        
        # Detect repository visibility
        $repoVisibility = Get-RepositoryVisibility -Repo $GitHubRepo
        if ($repoVisibility -eq "private") {
            Write-Info "Detected private repository, using authenticated access"
        } elseif ($repoVisibility -eq "public") {
            Write-Info "Detected public repository"
        } else {
            Write-Warn "Could not determine repository visibility"
        }
        
        $response = Invoke-ApiRequest -Url $apiUrl
        
        if ($PreRelease) {
            # Get the first (latest) release from the array, whether it's a pre-release or not
            if ($response -is [array] -and $response.Count -gt 0) {
                return $response[0].tag_name
            } else {
                throw "No releases found"
            }
        } else {
            # Get latest stable release
            return $response.tag_name
        }
    } catch {
        if ($repoVisibility -eq "private") {
            Write-Error-Custom "Could not fetch latest version from private repository"
            Write-Error-Custom "Please ensure you have access to $GitHubRepo"
            Write-Error-Custom "Check your Git credentials: git credential fill"
            exit 1
        } else {
            Write-Error-Custom "Failed to fetch latest version from GitHub API"
            Write-Error-Custom "Please specify a version using -Version parameter or FLOWSPACE_VERSION environment variable"
            exit 1
        }
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
    
    $ArchiveName = "flowspace-v$CleanVersion-windows-$Architecture.tar.gz"
    $BinaryNameInArchive = "flowspace-windows-$Architecture.exe"
    
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
            # Download from HTTP/HTTPS with authentication if available
            $token = Get-GitHubToken
            $downloadSuccess = $false
            
            if ($token -and $DownloadUrl -like "*github.com*") {
                Write-Info "Using authenticated download"
                try {
                    $headers = @{
                        "Authorization" = "token $token"
                        "Accept" = "application/octet-stream"
                    }
                    Invoke-WebRequest -Uri $DownloadUrl -OutFile $ArchivePath -Headers $headers -UseBasicParsing
                    $downloadSuccess = $true
                } catch {
                    Write-Warn "Authenticated download failed, trying unauthenticated"
                }
            }
            
            # Fallback to unauthenticated download
            if (-not $downloadSuccess) {
                Invoke-WebRequest -Uri $DownloadUrl -OutFile $ArchivePath -UseBasicParsing
            }
        }
    } catch {
        Write-Error-Custom "Failed to download $ArchiveName"
        Write-Error-Custom "Please check if version $Version exists for windows/$Architecture"
        if ($token) {
            Write-Error-Custom "Tried both authenticated and unauthenticated downloads"
            Write-Error-Custom "Repository may be private - ensure you have access to $GitHubRepo"
        }
        exit 1
    }
    
    # Verify the download
    if (-not (Test-Path $ArchivePath) -or (Get-Item $ArchivePath).Length -eq 0) {
        Write-Error-Custom "Downloaded file is empty or does not exist"
        exit 1
    }
    
    # Verify checksum if available
    $expectedChecksum = Get-ReleaseChecksum -Version $Version -ArchiveName $ArchiveName
    if (-not (Test-FileChecksum -FilePath $ArchivePath -ExpectedChecksum $expectedChecksum)) {
        Write-Error-Custom "Checksum verification failed - aborting installation for security"
        exit 1
    }
    
    Write-Info "Extracting archive..."
    
    # Create temporary extraction directory
    $ExtractDir = Join-Path $TempDir "flowspace-extract-$(Get-Random)"
    
    try {
        # Extract the archive (handle both .zip and .tar.gz)
        if ($ArchiveName.EndsWith(".zip")) {
            Expand-Archive -Path $ArchivePath -DestinationPath $ExtractDir -Force
        } elseif ($ArchiveName.EndsWith(".tar.gz")) {
            # For .tar.gz files, we need to use tar if available, or 7-Zip
            if (Get-Command tar -ErrorAction SilentlyContinue) {
                & tar -xzf $ArchivePath -C $ExtractDir
            } else {
                Write-Error-Custom "tar command not found. Please install Git for Windows or 7-Zip to extract .tar.gz files"
                exit 1
            }
        } else {
            Write-Error-Custom "Unsupported archive format: $ArchiveName"
            exit 1
        }
        
        # Find the binary in the extracted files
        $ExtractedBinary = Join-Path $ExtractDir $BinaryNameInArchive
        if (-not (Test-Path $ExtractedBinary)) {
            Write-Error-Custom "Binary $BinaryNameInArchive not found in archive"
            Write-Info "Archive contents:"
            Get-ChildItem $ExtractDir | ForEach-Object { Write-Info "  $($_.Name)" }
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
                Write-Info "For immediate use in this session, run:"
                Write-Info "  `$env:PATH = `"`$env:PATH;$InstallDir`""
                Write-Info "  flowspace --help"
                Write-Info ""
                Write-Info "Or you can run the binary directly:"
                Write-Info "  $BinaryPath --help"
            } else {
                Write-Info "You can now run: flowspace --help"
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
