# Flowspace

Welcome to the official Flowspace releases repository. This repository contains release pa## Usage

After installation, Flowspace provides a powerful CLI and MCP server for semantic codebase analysis:

### 🚀 Getting Started

```bash
# Initialize flowspace in current repository (required first step)
flowspace init
```

### 🔧 Core Pipeline

```bash
# Complete pipeline with all analysis stages
flowspace full-scan
```lation scripts for Flowspace.

> ⚠️ **CRITICAL SECURITY WARNING** ⚠️
>
> **DO NOT USE WITH UNAPPROVED MODELS.** This tool provides LLMs with full access to entire codebases through its MCP server. Using Substrate/Flowspace with an unapproved model is equivalent to giving that model direct, unrestricted access to your codebase.
>
> **EXERCISE EXTREME CAUTION** when using the MCP server with tools like Claude Code or any other LLM-powered coding assistants. Only use models that have been explicitly approved by your organization's security team for handling sensitive code.
>
> By design, Substrate grants comprehensive codebase access to enable powerful context-aware features. Ensure you understand and accept these security implications before use.

## Installation

### Quick Install (Recommended)

```bash
curl -L https://aka.ms/InstallFlowspace | bash
```

### Install Pre-Release Version

To install the latest pre-release version (including beta releases):

```bash
curl -L https://aka.ms/InstallFlowspace | FLOWSPACE_PRE_RELEASE=true bash
```

### Manual Installation

You can also download and run the installation script manually:

```bash
# Download and run with options
wget https://raw.githubusercontent.com/AI-Substrate/flowspace/main/scripts/install-flowspace.sh
chmod +x install-flowspace.sh

# Install latest stable version
./install-flowspace.sh

# Install latest pre-release version
./install-flowspace.sh --pre-release

# Install specific version
./install-flowspace.sh --version v1.0.0

# Install to custom directory
./install-flowspace.sh --install-dir /usr/local/bin
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
  - Linux: Debian/Ubuntu, RHEL/CentOS/Fedora
  - macOS: Intel and Apple Silicon
  - Windows: x86_64, arm64
- **Container Support**: Docker (all platforms)
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
  - Pre-release versions (`--pre-release` or `FLOWSPACE_PRE_RELEASE`)
  - Custom installation directories (`--install-dir` or `FLOWSPACE_INSTALL_DIR`)
  - Force reinstall (`--force` or `FLOWSPACE_FORCE`)
  - Local/custom download URLs (`--base-url` or `FLOWSPACE_BASE_URL`)
  - Checksum verification for security
  - Git Credential Manager integration for private repos

## Usage

After installation, Flowspace provides a powerful CLI and MCP server for semantic codebase analysis:

### � Getting Started

```bash
# Initialize flowspace in current repository (required first step)
flowspace init
```

### �🔧 Core Pipeline

```bash
# Complete pipeline with all analysis stages
flowspace full-scan
```

### 🔍 Analysis & Query

```bash
# Search code using natural language
flowspace query "find authentication patterns"

# Analyze architectural patterns
flowspace analyze-relationships

# Get detailed information about a specific node with relationships
flowspace get-node <node-id>

# List all node IDs from a condensed file
flowspace list-node-ids

# Interactive relationship viewer
flowspace view-relationships

# List available report plugins
flowspace list-interesting-reports
```

### 📄 Documentation

```bash
# Generate documentation from analysis
flowspace document
```

### 📦 Repository Management

```bash
# Add a repository to the registry
flowspace repo add <repository-url>

# List all registered repositories
flowspace repo list

# Remove a repository from the registry
flowspace repo remove <repository-name>
```

### 🔧 Utilities

```bash
# Clone a repository
flowspace clone <repository-url>

# Analyze code structure (basic)
flowspace analyze

# Pre-build graph cache from condensed file
flowspace build-graph
```

### 🤖 LLM Integration

```bash
# Launch MCP server for LLM agent integration
flowspace mcp
```

## Support

- **Documentation**: Available in the main repository
- **Issues**: [GitHub Issues](https://github.com/AI-Substrate/flowspace/issues)
- **Discussions**: [GitHub Discussions](https://github.com/AI-Substrate/flowspace/discussions)

---

© 2025 AI-Substrate. All rights reserved.
