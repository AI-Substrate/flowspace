#!/bin/bash
# Flowspace (Substrate) Installation Script
# Supports: Debian/Ubuntu, RHEL/CentOS/Fedora, Alpine Linux
# Usage: curl -L https://aka.ms/InstallFlowspace | bash
#   or:  bash install-flowspace.sh [OPTIONS]
#   or:  FLOWSPACE_BASE_URL="file:///path/to/releases" bash install-flowspace.sh
#
# Command line options:
#   -f, --force             Force reinstall if already exists
#   -v, --version VERSION   Install specific version (default: latest)
#   -d, --install-dir DIR   Installation directory (default: ~/.local/bin)
#   --base-url URL          Override download URL (supports file://)
#   --no-gcm                Disable Git Credential Manager authentication
#   -h, --help              Show help message
#
# Environment variables:
#   FLOWSPACE_BASE_URL     - Override download URL (supports file:// for local testing)
#   FLOWSPACE_INSTALL_DIR  - Installation directory (default: ~/.local/bin)
#   FLOWSPACE_VERSION      - Version to install (default: latest)
#   FLOWSPACE_FORCE        - Force reinstall if already exists (default: false)
#   FLOWSPACE_USE_GCM_AUTH - Use Git Credential Manager for GitHub auth (default: true)

set -euo pipefail

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -f|--force)
            FORCE_INSTALL="true"
            shift
            ;;
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
        -h|--help)
            cat << EOF
Flowspace (Substrate) Installation Script

Usage: $0 [OPTIONS]

Options:
    -f, --force             Force reinstall if already exists
    -v, --version VERSION   Install specific version (default: latest)
    -d, --install-dir DIR   Installation directory (default: ~/.local/bin)
    --base-url URL          Override download URL (supports file://)
    --no-gcm                Disable Git Credential Manager authentication
    -h, --help              Show this help message

Environment variables:
    FLOWSPACE_BASE_URL      Override download URL
    FLOWSPACE_INSTALL_DIR   Installation directory (default: ~/.local/bin)
    FLOWSPACE_VERSION       Version to install
    FLOWSPACE_FORCE         Force reinstall (true/false)
    FLOWSPACE_USE_GCM_AUTH  Use Git Credential Manager (true/false)

Examples:
    $0                                    # Install latest version
    $0 --force                           # Force reinstall
    $0 --version v1.0.0                  # Install specific version
    $0 --install-dir /usr/local/bin      # Install to system directory
    $0 --base-url file:///path/to/files  # Install from local files

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
FORCE_INSTALL="${FLOWSPACE_FORCE:-${FORCE_INSTALL:-false}}"
BASE_URL="${FLOWSPACE_BASE_URL:-${BASE_URL:-}}"
USE_GCM_AUTH="${FLOWSPACE_USE_GCM_AUTH:-${USE_GCM_AUTH:-false}}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
info() { echo -e "${BLUE}[INFO]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }

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
    for cmd in curl tar; do
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
                apt-get update -qq
                apt-get install -y "${missing_deps[@]}"
            else
                error "apt-get not found on Debian-based system"
                exit 1
            fi
            ;;
        rhel)
            if command -v dnf >/dev/null 2>&1; then
                dnf install -y "${missing_deps[@]}"
            elif command -v yum >/dev/null 2>&1; then
                yum install -y "${missing_deps[@]}"
            else
                error "Neither dnf nor yum found on RHEL-based system"
                exit 1
            fi
            ;;
        alpine)
            if command -v apk >/dev/null 2>&1; then
                apk add --no-cache "${missing_deps[@]}"
            else
                error "apk not found on Alpine system"
                exit 1
            fi
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

# Get checksum for a specific release asset
get_release_checksum() {
    local version="$1"
    local archive_name="$2"
    
    local checksums_url
    if [[ -n "$BASE_URL" ]]; then
        checksums_url="$BASE_URL/checksums.txt"
    else
        checksums_url="https://github.com/$GITHUB_REPO/releases/download/$version/checksums.txt"
    fi
    
    info "Fetching checksums..." >&2
    
    local checksum
    if [[ "$checksums_url" == file://* ]]; then
        # Handle file:// URLs
        local file_path="${checksums_url#file://}"
        if [[ -f "$file_path" ]]; then
            checksum=$(grep "$archive_name" "$file_path" 2>/dev/null | cut -d' ' -f1 || echo "")
        fi
    else
        # Handle HTTP/HTTPS URLs with authentication if available
        local token
        if token=$(get_github_token) && [[ "$checksums_url" == *"github.com"* ]]; then
            checksum=$(curl -H "Authorization: token $token" -sSfL "$checksums_url" 2>/dev/null | grep "$archive_name" | cut -d' ' -f1 || echo "")
        else
            checksum=$(curl -sSfL "$checksums_url" 2>/dev/null | grep "$archive_name" | cut -d' ' -f1 || echo "")
        fi
    fi
    
    echo "$checksum"
}

# Get the latest release version from GitHub
get_latest_version() {
    local api_url="https://api.github.com/repos/$GITHUB_REPO/releases/latest"
    local version
    local repo_visibility
    
    info "Fetching latest version from GitHub..." >&2
    
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
        version=$(api_request "$api_url" | jq -r '.tag_name' 2>/dev/null || echo "")
    else
        # Fallback without jq
        version=$(api_request "$api_url" | grep -oP '"tag_name":\s*"\K[^"]+' 2>/dev/null || echo "")
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
    
    # Check if binary already exists
    if [[ -f "$INSTALL_DIR/$BINARY_NAME" ]] && [[ "$FORCE_INSTALL" != "true" ]]; then
        local existing_version
        existing_version=$("$INSTALL_DIR/$BINARY_NAME" --version 2>/dev/null | head -n1 || echo "unknown")
        warn "Flowspace is already installed: $existing_version"
        warn "Use FLOWSPACE_FORCE=true to overwrite"
        rm -rf "$temp_dir"
        exit 1
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
        local version_output
        version_output=$("$INSTALL_DIR/$BINARY_NAME" --version 2>/dev/null || echo "Version check failed")
        success "Installation verified: $version_output"
        
        # Check if install directory is in PATH
        if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
            warn "Install directory $INSTALL_DIR is not in your PATH"
            
            # Provide platform-specific shell profile guidance
            local os
            os=$(uname -s)
            case $os in
                Darwin)
                    info "Add it to your PATH by adding this line to your shell profile:"
                    if [[ "$SHELL" == *"zsh"* ]] || [[ -n "${ZSH_VERSION:-}" ]]; then
                        info "  echo 'export PATH=\"$INSTALL_DIR:\$PATH\"' >> ~/.zshrc"
                        info "  source ~/.zshrc"
                    else
                        info "  echo 'export PATH=\"$INSTALL_DIR:\$PATH\"' >> ~/.bash_profile"
                        info "  source ~/.bash_profile"
                    fi
                    ;;
                Linux|*)
                    info "Add it to your PATH by adding this line to your shell profile:"
                    if [[ "$SHELL" == *"zsh"* ]] || [[ -n "${ZSH_VERSION:-}" ]]; then
                        info "  echo 'export PATH=\"$INSTALL_DIR:\$PATH\"' >> ~/.zshrc"
                        info "  source ~/.zshrc"
                    else
                        info "  echo 'export PATH=\"$INSTALL_DIR:\$PATH\"' >> ~/.bashrc"
                        info "  source ~/.bashrc"
                    fi
                    ;;
            esac
            
            info ""
            info "For immediate use in this session, run:"
            info "  export PATH=\"$INSTALL_DIR:\$PATH\""
            info "  $BINARY_NAME --help"
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
