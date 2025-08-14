# Flowspace

Welcome to the official Flowspace releases repository. This repository contains release packages and installation scripts for Flowspace.

## Installation

### Quick Install (Recommended)

```bash
curl -L https://aka.ms/InstallFlowspace | bash
```

### Windows (PowerShell)
```powershell
Invoke-RestMethod https://aka.ms/InstallFlowspace | Invoke-Expression
```

### Manual Installation

1. Download the latest release from the [Releases](https://github.com/AI-Substrate/flowspace/releases) page
2. Extract the archive to your desired location
3. Run the installation script:
   ```bash
   ./scripts/install-flowspace.sh
   ```
   
   For Windows:
   ```powershell
   .\scripts\install-flowspace.ps1
   ```

## What is Flowspace?

Flowspace (formerly Substrate) is your **Context Engineer** - an advanced semantic codebase analysis tool designed specifically for LLM coding agents. It performs deep semantic scans of entire codebases, creating comprehensive relationship graphs between all files, classes, methods, and concepts.

### Key Features

- **Semantic Code Understanding**: Creates detailed relationships between all code elements using AST parsing and SCIP analysis
- **Cross-Repository Intelligence**: Can analyze local repos or remote repositories, building a knowledge graph across your entire organization
- **Smart Content Generation**: Uses LLMs to generate intelligent summaries and embeddings for every code element
- **Vector Search**: Find code concepts semantically, like "automated testing for Microsoft Fabric" or "plugin for our Flutter app"
- **Context Engineering**: Provides LLM agents with immediate, comprehensive codebase knowledge for faster development
- **Multi-Language Support**: Works with many programming languages through Tree-Sitter and specialized parsers
- **Fast Graph Storage**: Uses NetworkX for high-performance graph operations that scale to hundreds of thousands of nodes

Flowspace enables coding agents to instantly "know" your code, dramatically reducing the time needed to understand context and implement features across complex codebases.

## System Requirements

- **Operating System**: Linux, macOS, Windows (with WSL)
- **Architecture**: x86_64 (amd64), aarch64/arm64 (Apple Silicon)
- **Platform Support**:
  - Linux: Debian/Ubuntu, RHEL/CentOS/Fedora, Alpine Linux
  - macOS: Intel and Apple Silicon
  - Windows: x86_64, arm64
- **Installation**: No admin privileges required (installs to `~/.local/bin`)
- **Dependencies**: Git (optional, for authenticated downloads)

## Releases

All releases are available on the [Releases](https://github.com/AI-Substrate/flowspace/releases) page. Each release includes:

- Pre-compiled binaries for supported platforms
- Installation scripts
- Documentation
- Changelog

## Installation Scripts

This repository contains installation scripts in the `/scripts` folder:

- `scripts/install-flowspace.sh` - Main installation script for Linux/macOS with comprehensive options
- `scripts/install-flowspace.ps1` - Installation script for Windows PowerShell
- Both scripts support:
  - Version selection (`--version` or `FLOWSPACE_VERSION`)
  - Custom installation directories (`--install-dir` or `FLOWSPACE_INSTALL_DIR`)
  - Force reinstall (`--force` or `FLOWSPACE_FORCE`)
  - Local/custom download URLs (`--base-url` or `FLOWSPACE_BASE_URL`)
  - Checksum verification for security
  - Git Credential Manager integration for private repos

## Usage

After installation, Flowspace provides a powerful CLI and MCP server for semantic codebase analysis:

### Basic Commands

```bash
# Analyze your current repository
flowspace scan

# Search for code semantically
flowspace search "automated testing patterns"

# Query specific nodes and relationships
flowspace query --node-id "method:src/example.py:MyClass.my_method"

# Generate analysis reports
flowspace report --format markdown

# Start MCP server for LLM integration
flowspace mcp-server
```

### Advanced Features

```bash
# Search with embeddings
flowspace search -E "error handling patterns"

# Output in different formats
flowspace query --output json
flowspace query --output table
flowspace query --output pretty

# Generate visualization data
flowspace graph-viz
```

## Support

- **Documentation**: Available in the main repository
- **Issues**: [GitHub Issues](https://github.com/AI-Substrate/flowspace/issues)
- **Discussions**: [GitHub Discussions](https://github.com/AI-Substrate/flowspace/discussions)

---

© 2025 AI-Substrate. All rights reserved.
