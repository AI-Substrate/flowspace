#!/bin/bash
# Flowspace (Substrate) Installation Script
# Supports: Debian/Ubuntu, RHEL/CentOS/Fedora
# Usage: curl -L https://aka.ms/InstallFlowspace | bash
#   or:  curl -L https://aka.ms/InstallFlowspace | FLOWSPACE_PRE_RELEASE=true bash
#   or:  bash install-flowspace.sh [OPTIONS]
#   or:  FLOWSPACE_BASE_URL="file:///path/to/releases" bash install-flowspace.sh
#
# Command line options:
#   -v, --version VERSION   Install specific version (default: latest)
#   -d, --install-dir DIR   Installation directory (default: ~/.local/bin)
#   --base-url URL          Override download URL (supports file://)
#   --no-gcm                Disable Git Credential Manager authentication
#   --pre-release           Include pre-release versions when fetching latest
#   -h, --help              Show help message
#
# Environment variables:
#   FLOWSPACE_BASE_URL     - Override download URL (supports file:// for local testing)
#   FLOWSPACE_INSTALL_DIR  - Installation directory (default: ~/.local/bin)
#   FLOWSPACE_VERSION      - Version to install (default: latest)
#   FLOWSPACE_USE_GCM_AUTH - Use Git Credential Manager for GitHub auth (default: true)
#   FLOWSPACE_PRE_RELEASE  - Include pre-release versions (default: false)

set -euo pipefail

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -v|--version)
            VERSION="$2"
            shift 2
            ;;
        -d|--dir|--install-dir)
            INSTALL_DIR="$2"
            shift 2
            ;;
        --base-url)
            BASE_URL="$2"
            shift 2
            ;;
        --no-gcm)
            USE_GCM_AUTH="false"
            shift
            ;;
        --pre-release)
            PRE_RELEASE="true"
            shift
            ;;
        -h|--help)
            cat << EOF
Flowspace (Substrate) Installation Script

Usage: $0 [OPTIONS]

Options:
    -v, --version VERSION   Install specific version (default: latest)
    -d, --install-dir DIR   Installation directory (default: ~/.local/bin)
    --base-url URL          Override download URL (supports file://)
    --no-gcm                Disable Git Credential Manager authentication
    --pre-release           Include pre-release versions when fetching latest
    -h, --help              Show this help message

Environment variables:
    FLOWSPACE_BASE_URL      Override download URL
    FLOWSPACE_INSTALL_DIR   Installation directory (default: ~/.local/bin)
    FLOWSPACE_VERSION       Version to install
    FLOWSPACE_USE_GCM_AUTH  Use Git Credential Manager (true/false)
    FLOWSPACE_PRE_RELEASE   Include pre-release versions (true/false)

Examples:
    $0                                    # Install latest version
    $0 --version v1.0.0                  # Install specific version
    $0 --install-dir /usr/local/bin      # Install to system directory
    $0 --pre-release                     # Install latest including pre-releases
    $0 --base-url file:///path/to/files  # Install from local files

Quick install examples:
    curl -L https://aka.ms/InstallFlowspace | bash
    curl -L https://aka.ms/InstallFlowspace | FLOWSPACE_PRE_RELEASE=true bash

EOF
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            echo "Use --help for usage information" >&2
            exit 1
            ;;
    esac
done

# Determine the best default installation directory based on platform
get_default_install_dir() {
    # Simplified: use ~/.local/bin on all platforms for consistency
    # It's part of the XDG Base Directory Specification and works everywhere
    echo "$HOME/.local/bin"
}

# Configuration (can be overridden by environment variables or command line)
GITHUB_REPO="AI-Substrate/flowspace"
BINARY_NAME="flowspace"
INSTALL_DIR="${FLOWSPACE_INSTALL_DIR:-${INSTALL_DIR:-$(get_default_install_dir)}}"
VERSION="${FLOWSPACE_VERSION:-${VERSION:-latest}}"
BASE_URL="${FLOWSPACE_BASE_URL:-${BASE_URL:-}}"
USE_GCM_AUTH="${FLOWSPACE_USE_GCM_AUTH:-${USE_GCM_AUTH:-false}}"
PRE_RELEASE="${FLOWSPACE_PRE_RELEASE:-${PRE_RELEASE:-false}}"

# Logging functions
info() { echo "$*"; }
warn() { echo "⚠️  $*"; }
error() { echo "❌  $*" >&2; }
success() { echo "✅ $*"; }

# Container and Docker detection functions
detect_container_environment() {
    # Check for .dockerenv file (most reliable)
    if [[ -f "/.dockerenv" ]]; then
        return 0
    fi
    
    # Check cgroup for container indicators
    if [[ -f "/proc/1/cgroup" ]]; then
        local cgroup_content
        cgroup_content=$(cat /proc/1/cgroup 2>/dev/null || echo "")
        if [[ "$cgroup_content" == *"docker"* ]] || \
           [[ "$cgroup_content" == *"kubepods"* ]] || \
           [[ "$cgroup_content" == *"containerd"* ]]; then
            return 0
        fi
    fi
    
    return 1
}

check_docker_availability() {
    # Check if Docker socket is available
    if [[ -S "/var/run/docker.sock" ]]; then
        return 0
    fi
    
    # Check if docker command is available and can connect
    if command -v docker >/dev/null 2>&1; then
        if docker info >/dev/null 2>&1; then
            return 0
        fi
    fi
    
    return 1
}

validate_docker_environment() {
    local in_container
    local docker_available
    
    in_container=$(detect_container_environment && echo "true" || echo "false")
    docker_available=$(check_docker_availability && echo "true" || echo "false")
    
    if [[ "$in_container" == "true" ]]; then
        info "Detected container environment (likely devcontainer)"
        
        if [[ "$docker_available" == "true" ]]; then
            info "Docker is available (Docker-in-Docker or Docker-outside-of-Docker setup detected)"
        else
            error "Running in container but Docker is not accessible"
            error "Flowspace requires Docker access to function properly"
            error ""
            error "For devcontainers, you need either:"
            error "  1. Docker-in-Docker: Add 'docker-in-docker' feature to devcontainer.json"
            error "  2. Docker-outside-of-Docker: Add 'docker-outside-of-docker' feature to devcontainer.json"
            error ""
            exit 1
        fi
    else
        # Not in container - check if Docker is installed
        if [[ "$docker_available" != "true" ]]; then
            error "Docker is not installed or not running"
            error "Flowspace requires Docker to function properly"
            error ""
            error "Please install Docker first:"
            error "  • macOS: Download Docker Desktop from https://docker.com/products/docker-desktop"
            error "  • Linux: Follow instructions at https://docs.docker.com/engine/install/"
            error "  • Windows: Download Docker Desktop from https://docker.com/products/docker-desktop"
            error ""
            error "After installing Docker, make sure it's running and try again."
            exit 1
        fi
    fi
    
    success "Docker environment validated successfully"
}

# Git Credential Manager integration
get_github_token() {
    if [[ "$USE_GCM_AUTH" != "true" ]]; then
        return 1
    fi
    
    if ! command -v git >/dev/null 2>&1; then
        return 1
    fi
    
    local token
    token=$(git credential fill <<EOF 2>/dev/null | grep '^password=' | cut -d= -f2
protocol=https
host=github.com
EOF
)
    
    if [[ -n "$token" ]]; then
        echo "$token"
        return 0
    else
        return 1
    fi
}

# Check if repository is private by trying public API first
detect_repo_visibility() {
    local repo="$1"
    
    # Try public API first (no auth needed)
    if curl -sSfL --max-time 10 "https://api.github.com/repos/$repo" >/dev/null 2>&1; then
        echo "public"
        return 0
    fi
    
    # Try with authentication if available
    local token
    if token=$(get_github_token); then
        if curl -H "Authorization: token $token" \
               -sSfL --max-time 10 "https://api.github.com/repos/$repo" >/dev/null 2>&1; then
            echo "private"
            return 0
        fi
    fi
    
    echo "unknown"
    return 1
}

# Make authenticated API request if token available, otherwise unauthenticated
api_request() {
    local url="$1"
    local token
    
    if token=$(get_github_token); then
        local response
        local http_code
        response=$(curl -w "%{http_code}" -H "Authorization: token $token" -sSfL "$url" 2>&1)
        http_code="${response: -3}"
        if [[ "$http_code" != "200" ]]; then
            warn "API request failed with HTTP $http_code for: $url" >&2
            return 1
        fi
        echo "${response%???}"  # Remove last 3 characters (HTTP code)
    else
        local response
        local http_code
        response=$(curl -w "%{http_code}" -sSfL "$url" 2>&1)
        http_code="${response: -3}"
        if [[ "$http_code" != "200" ]]; then
            warn "API request failed with HTTP $http_code for: $url" >&2
            return 1
        fi
        echo "${response%???}"  # Remove last 3 characters (HTTP code)
    fi
}

# Check if running as root for system-wide install
check_permissions() {
    if [[ "$INSTALL_DIR" == /usr/* ]] || [[ "$INSTALL_DIR" == /bin ]] || [[ "$INSTALL_DIR" == /sbin ]]; then
        if [[ $EUID -ne 0 ]]; then
            error "Installing to $INSTALL_DIR requires root privileges."
            info "For system-wide installation, run with sudo:"
            info "  sudo FLOWSPACE_INSTALL_DIR=$INSTALL_DIR bash -c \"\$(curl -L https://aka.ms/InstallFlowspace)\""
            info ""
            info "Or use the default user installation (recommended):"
            info "  curl -L https://aka.ms/InstallFlowspace | bash"
            exit 1
        fi
    fi
}

# Detect architecture
detect_arch() {
    local arch
    arch=$(uname -m)
    case $arch in
        x86_64) echo "amd64" ;;
        aarch64|arm64) echo "arm64" ;;
        *)
            error "Unsupported architecture: $arch"
            info "Supported architectures: x86_64 (amd64), aarch64/arm64"
            exit 1
            ;;
    esac
}

# Detect OS
detect_os() {
    local os
    os=$(uname -s)
    case $os in
        Linux) echo "linux" ;;
        Darwin) echo "darwin" ;;
        CYGWIN*|MINGW*|MSYS*|Windows*)
            error "Windows detected! Please use the PowerShell installer instead:"
            info "  Invoke-RestMethod https://aka.ms/InstallFlowspace | Invoke-Expression"
            info ""
            info "Or download and run the PowerShell script manually:"
            info "  Invoke-WebRequest -Uri https://raw.githubusercontent.com/mcaps-microsoft/flowspace/main/scripts/install-flowspace.ps1 -OutFile install-flowspace.ps1"
            info "  .\\install-flowspace.ps1"
            exit 1
            ;;
        *)
            error "Unsupported operating system: $os"
            info "This script is designed for Linux and macOS systems"
            info "For Windows, use the PowerShell installer:"
            info "  Invoke-RestMethod https://aka.ms/InstallFlowspace | Invoke-Expression"
            exit 1
            ;;
    esac
}

# Helper function to run commands with appropriate privileges
run_with_privileges() {
    if [[ $EUID -eq 0 ]]; then
        # Already running as root
        "$@"
    else
        # Not root, use sudo
        sudo "$@"
    fi
}

# Detect OS distribution/platform for package manager operations
detect_distro() {
    local os
    os=$(uname -s)
    
    case $os in
        Darwin)
            echo "macos"
            return 0
            ;;
        Linux)
            # Linux distribution detection
            if [[ -f /etc/os-release ]]; then
                . /etc/os-release
                case $ID in
                    ubuntu|debian) echo "debian" ;;
                    rhel|centos|fedora|rocky|almalinux) echo "rhel" ;;
                    alpine) echo "alpine" ;;
                    *) echo "unknown" ;;
                esac
            elif command -v apk >/dev/null 2>&1; then
                echo "alpine"
            elif command -v apt-get >/dev/null 2>&1; then
                echo "debian"
            elif command -v yum >/dev/null 2>&1 || command -v dnf >/dev/null 2>&1; then
                echo "rhel"
            else
                echo "unknown"
            fi
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

# Install required dependencies
install_dependencies() {
    local distro="$1"
    local missing_deps=()
    
    # Check for required tools
    for cmd in curl tar jq; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing_deps+=("$cmd")
        fi
    done
    
    # Check for checksum tools (different on different platforms)
    if ! command -v sha256sum >/dev/null 2>&1 && ! command -v shasum >/dev/null 2>&1; then
        case $distro in
            macos)
                # macOS has shasum by default, but we'll add coreutils for sha256sum if needed
                if ! command -v shasum >/dev/null 2>&1; then
                    missing_deps+=("coreutils")
                fi
                ;;
            *)
                missing_deps+=("coreutils")
                ;;
        esac
    fi
    
    if [[ ${#missing_deps[@]} -eq 0 ]]; then
        return 0
    fi
    
    info "Installing missing dependencies: ${missing_deps[*]}"
    
    case $distro in
        macos)
            if command -v brew >/dev/null 2>&1; then
                info "Using Homebrew to install dependencies"
                brew install "${missing_deps[@]}"
            else
                warn "Homebrew not found. Please install manually:"
                info "  Install Homebrew: /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
                info "  Then install dependencies: brew install ${missing_deps[*]}"
                info ""
                info "Or install missing tools manually:"
                for dep in "${missing_deps[@]}"; do
                    case $dep in
                        curl) info "  curl is usually pre-installed on macOS" ;;
                        tar) info "  tar is usually pre-installed on macOS" ;;
                        coreutils) info "  coreutils: brew install coreutils (for sha256sum)" ;;
                        *) info "  $dep: check https://formulae.brew.sh/formula/$dep" ;;
                    esac
                done
                exit 1
            fi
            ;;
        debian)
            if command -v apt-get >/dev/null 2>&1; then
                run_with_privileges apt-get update -qq
                run_with_privileges apt-get install -y "${missing_deps[@]}"
            else
                error "apt-get not found on Debian-based system"
                exit 1
            fi
            ;;
        rhel)
            if command -v dnf >/dev/null 2>&1; then
                run_with_privileges dnf install -y "${missing_deps[@]}"
            elif command -v yum >/dev/null 2>&1; then
                run_with_privileges yum install -y "${missing_deps[@]}"
            else
                error "Neither dnf nor yum found on RHEL-based system"
                exit 1
            fi
            ;;
        alpine)
            error "Alpine Linux support is currently not available"
            error "Please use a different Linux distribution or Docker"
            exit 1
            ;;
        *)
            error "Unknown distribution: $distro"
            error "Please manually install missing dependencies: ${missing_deps[*]}"
            exit 1
            ;;
    esac
}

# Verify file checksum
verify_checksum() {
    local file_path="$1"
    local expected_checksum="$2"
    
    if [[ -z "$expected_checksum" ]]; then
        warn "No checksum provided - skipping verification"
        return 0
    fi
    
    info "Verifying file integrity..."
    
    local actual_checksum
    if command -v sha256sum >/dev/null 2>&1; then
        actual_checksum=$(sha256sum "$file_path" | cut -d' ' -f1)
    elif command -v shasum >/dev/null 2>&1; then
        actual_checksum=$(shasum -a 256 "$file_path" | cut -d' ' -f1)
    else
        warn "No checksum tool available (sha256sum/shasum) - skipping verification"
        return 0
    fi
    
    if [[ "$actual_checksum" == "$expected_checksum" ]]; then
        success "Checksum verification passed"
        return 0
    else
        error "Checksum verification failed!"
        error "Expected: $expected_checksum"
        error "Actual:   $actual_checksum"
        error "This could indicate a corrupted download or security issue"
        return 1
    fi
}

# Get checksum for a specific release asset from GitHub API
get_release_checksum() {
    local version="$1"
    local archive_name="$2"
    
    info "Fetching asset checksum from GitHub API..." >&2
    
    local api_url="https://api.github.com/repos/$GITHUB_REPO/releases/tags/$version"
    local checksum=""
    
    # Try to get asset info from GitHub API
    local release_data
    if release_data=$(api_request "$api_url" 2>/dev/null); then
        # Extract the digest for the specific asset
        if command -v jq >/dev/null 2>&1; then
            # Use jq if available for robust JSON parsing
            checksum=$(echo "$release_data" | jq -r --arg name "$archive_name" '.assets[] | select(.name == $name) | .digest // empty' 2>/dev/null | sed 's/^sha256://' || echo "")
        else
            # Fallback without jq - look for the asset and extract digest
            # This is more fragile but works without jq dependency
            local asset_section
            asset_section=$(echo "$release_data" | grep -A 20 "\"name\": \"$archive_name\"" 2>/dev/null || echo "")
            if [[ -n "$asset_section" ]]; then
                checksum=$(echo "$asset_section" | grep '"digest"' | head -1 | sed 's/.*"digest": *"sha256:\([^"]*\)".*/\1/' 2>/dev/null || echo "")
            fi
        fi
    fi
    
    # If GitHub API doesn't provide digest, try fallback to checksums.txt
    if [[ -z "$checksum" ]] && [[ -z "$BASE_URL" ]]; then
        warn "No digest available from GitHub API, trying checksums.txt fallback..." >&2
        local checksums_url="https://github.com/$GITHUB_REPO/releases/download/$version/checksums.txt"
        local token
        if token=$(get_github_token) && [[ "$checksums_url" == *"github.com"* ]]; then
            checksum=$(curl -H "Authorization: token $token" -sSfL "$checksums_url" 2>/dev/null | grep "$archive_name" | cut -d' ' -f1 || echo "")
        else
            checksum=$(curl -sSfL "$checksums_url" 2>/dev/null | grep "$archive_name" | cut -d' ' -f1 || echo "")
        fi
    elif [[ -n "$BASE_URL" ]]; then
        # Handle custom BASE_URL (for local testing)
        local checksums_url="$BASE_URL/checksums.txt"
        if [[ "$checksums_url" == file://* ]]; then
            local file_path="${checksums_url#file://}"
            if [[ -f "$file_path" ]]; then
                checksum=$(grep "$archive_name" "$file_path" 2>/dev/null | cut -d' ' -f1 || echo "")
            fi
        else
            checksum=$(curl -sSfL "$checksums_url" 2>/dev/null | grep "$archive_name" | cut -d' ' -f1 || echo "")
        fi
    fi
    
    echo "$checksum"
}

# Get the latest release version from GitHub
get_latest_version() {
    local api_url
    local version
    local repo_visibility
    
    # Choose API endpoint based on pre-release preference
    if [[ "$PRE_RELEASE" == "true" ]]; then
        api_url="https://api.github.com/repos/$GITHUB_REPO/releases"
        info "Fetching latest version (including pre-releases) from GitHub..." >&2
    else
        api_url="https://api.github.com/repos/$GITHUB_REPO/releases/latest"
        info "Fetching latest version from GitHub..." >&2
    fi
    
    # Detect if repo is private and show appropriate message
    repo_visibility=$(detect_repo_visibility "$GITHUB_REPO")
    if [[ "$repo_visibility" == "private" ]]; then
        info "Detected private repository, using authenticated access" >&2
    elif [[ "$repo_visibility" == "public" ]]; then
        info "Detected public repository" >&2
    else
        warn "Could not determine repository visibility" >&2
    fi
    
    # Try to get version from GitHub API with authentication if available
    if command -v jq >/dev/null 2>&1; then
        if [[ "$PRE_RELEASE" == "true" ]]; then
            # Get the first release from the list (could be pre-release)
            version=$(api_request "$api_url" | jq -r '.[0].tag_name' 2>/dev/null || echo "")
        else
            # Get latest stable release
            version=$(api_request "$api_url" | jq -r '.tag_name' 2>/dev/null || echo "")
        fi
    else
        # Fallback without jq
        if [[ "$PRE_RELEASE" == "true" ]]; then
            # Get the first release from the list
            version=$(api_request "$api_url" | grep -oP '"tag_name":\s*"\K[^"]+' | head -n1 2>/dev/null || echo "")
        else
            # Get latest stable release
            version=$(api_request "$api_url" | grep -oP '"tag_name":\s*"\K[^"]+' 2>/dev/null || echo "")
        fi
    fi
    
    if [[ -z "$version" ]] || [[ "$version" == "null" ]]; then
        if [[ "$repo_visibility" == "private" ]]; then
            error "Could not fetch latest version from private repository" >&2
            error "Please ensure you have access to $GITHUB_REPO" >&2
            error "Check your Git credentials: git credential fill" >&2
            exit 1
        else
            warn "Could not fetch latest version from GitHub API" >&2
            # Fallback to a known version pattern
            version="v0.0.1"
            warn "Using fallback version: $version" >&2
        fi
    fi
    
    echo "$version"
}

# Download and install the binary
install_binary() {
    local version="$1"
    local os="$2"
    local arch="$3"
    
    # Remove 'v' prefix if present
    local clean_version="${version#v}"
    
    local archive_name="flowspace-v${clean_version}-${os}-${arch}.tar.gz"
    local binary_name_in_archive="flowspace-${os}-${arch}"
    local download_url
    
    # Support BASE_URL override for testing with file:// or custom URLs
    if [[ -n "$BASE_URL" ]]; then
        download_url="$BASE_URL/$archive_name"
    else
        download_url="https://github.com/$GITHUB_REPO/releases/download/$version/$archive_name"
    fi
    
    local temp_dir
    temp_dir=$(mktemp -d)
    
    info "Downloading $archive_name..."
    info "URL: $download_url"
    
    # Download the archive (handle different URL types)
    if [[ "$download_url" == file://* ]]; then
        # Handle file:// URLs by copying the local file
        local file_path="${download_url#file://}"
        if [[ -f "$file_path" ]]; then
            info "Copying local file: $file_path"
            if ! cp "$file_path" "$temp_dir/$archive_name"; then
                error "Failed to copy local file $file_path"
                rm -rf "$temp_dir"
                exit 1
            fi
        else
            error "Local file not found: $file_path"
            rm -rf "$temp_dir"
            exit 1
        fi
    else
        # Handle HTTP/HTTPS URLs with authentication if available
        local token
        local download_success=false
        
        if token=$(get_github_token) && [[ "$download_url" == *"github.com"* ]]; then
            info "Using authenticated download"
            # Try authenticated download first
            if curl -H "Authorization: token $token" \
                    -H "Accept: application/octet-stream" \
                    -sSfL -o "$temp_dir/$archive_name" "$download_url"; then
                download_success=true
            else
                warn "Authenticated download failed, trying unauthenticated"
            fi
        fi
        
        # Fallback to unauthenticated download if auth failed or not available
        if [[ "$download_success" != "true" ]]; then
            if ! curl -sSfL -o "$temp_dir/$archive_name" "$download_url"; then
                error "Failed to download $archive_name"
                error "Please check if version $version exists for $os/$arch"
                if [[ -n "$token" ]]; then
                    error "Tried both authenticated and unauthenticated downloads"
                    error "Repository may be private - ensure you have access to $GITHUB_REPO"
                fi
                rm -rf "$temp_dir"
                exit 1
            fi
        fi
    fi
    
    # Verify the download
    if [[ ! -f "$temp_dir/$archive_name" ]] || [[ ! -s "$temp_dir/$archive_name" ]]; then
        error "Downloaded file is empty or does not exist"
        rm -rf "$temp_dir"
        exit 1
    fi
    
    # Verify checksum if available
    local expected_checksum
    expected_checksum=$(get_release_checksum "$version" "$archive_name")
    if ! verify_checksum "$temp_dir/$archive_name" "$expected_checksum"; then
        error "Checksum verification failed - aborting installation for security"
        rm -rf "$temp_dir"
        exit 1
    fi
    
    info "Extracting archive..."
    
    # Extract the archive
    if ! tar -xzf "$temp_dir/$archive_name" -C "$temp_dir"; then
        error "Failed to extract archive"
        rm -rf "$temp_dir"
        exit 1
    fi
    
    # Check if the binary exists in the extracted files
    if [[ ! -f "$temp_dir/$binary_name_in_archive" ]]; then
        error "Binary $binary_name_in_archive not found in archive"
        info "Archive contents:"
        ls -la "$temp_dir/"
        rm -rf "$temp_dir"
        exit 1
    fi
    
    # Create install directory if it doesn't exist
    if [[ ! -d "$INSTALL_DIR" ]]; then
        info "Creating install directory: $INSTALL_DIR"
        mkdir -p "$INSTALL_DIR"
    fi
    
    # Check if binary already exists and show info
    if [[ -f "$INSTALL_DIR/$BINARY_NAME" ]]; then
        info "Updating existing flowspace installation"
    fi
    
    info "Installing binary to $INSTALL_DIR/$BINARY_NAME..."
    
    # Install the binary
    cp "$temp_dir/$binary_name_in_archive" "$INSTALL_DIR/$BINARY_NAME"
    chmod +x "$INSTALL_DIR/$BINARY_NAME"
    
    # Cleanup
    rm -rf "$temp_dir"
    
    success "Flowspace installed successfully!"
}

# Verify installation
verify_installation() {
    if [[ -f "$INSTALL_DIR/$BINARY_NAME" ]]; then        
        # Check if install directory is in PATH
        if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
            warn "Install directory $INSTALL_DIR is not in your PATH"
            
            # Provide shell profile guidance based on existing files
            info "Add it to your PATH by adding this line to your shell profile:"
            
            # Check for existing profile files in order of preference
            # .zshrc, .bashrc, .bash_profile, .profile
            if [[ -f ~/.zshrc ]]; then
                echo "   echo 'export PATH=\"$INSTALL_DIR:\$PATH\"' >> ~/.zshrc"
                echo "   source ~/.zshrc"
            elif [[ -f ~/.bashrc ]]; then
                echo "   echo 'export PATH=\"$INSTALL_DIR:\$PATH\"' >> ~/.bashrc"
                echo "   source ~/.bashrc"
            elif [[ -f ~/.bash_profile ]]; then
                echo "   echo 'export PATH=\"$INSTALL_DIR:\$PATH\"' >> ~/.bash_profile"
                echo "   source ~/.bash_profile"
            elif [[ -f ~/.profile ]]; then
                echo "   echo 'export PATH=\"$INSTALL_DIR:\$PATH\"' >> ~/.profile"
                echo "   source ~/.profile"
            else
                # No profile files exist - suggest the most universal option
                echo "   echo 'export PATH=\"$INSTALL_DIR:\$PATH\"' >> ~/.profile"
                echo "   source ~/.profile"
                echo "   # Note: ~/.profile works with most shells (bash, zsh, etc.)"
            fi
            
            info ""
            info "For immediate use in this session, run:"
            echo "   export PATH=\"$INSTALL_DIR:\$PATH\""
            echo "   $BINARY_NAME --help"
        else
            info "You can now run: $BINARY_NAME --help"
        fi
    else
        error "Installation verification failed - binary not found"
        exit 1
    fi
}

# Main installation function
main() {
    info "Flowspace Installation Script"
    info "============================="
    
    # Detect system information
    local os arch distro
    os=$(detect_os)
    arch=$(detect_arch)
    distro=$(detect_distro)
    
    info "Detected system: $os/$arch ($distro distribution)"
    info "Install directory: $INSTALL_DIR"
    
    # Validate Docker environment
    validate_docker_environment
    
    # Check permissions
    check_permissions
    
    # Install dependencies
    install_dependencies "$distro"
    
    # Get version
    local install_version
    if [[ "$VERSION" == "latest" ]]; then
        install_version=$(get_latest_version)
        info "Installing version: $install_version"
    else
        install_version="$VERSION"
        info "Installing version: $install_version"
    fi
    
    # Install the binary
    install_binary "$install_version" "$os" "$arch"
    
    # Verify installation
    verify_installation
    
    success "Flowspace installation completed!"
}

# Handle script interruption
trap 'error "Installation interrupted"; exit 130' INT TERM

# Run main function
main "$@"
