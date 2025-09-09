# Flowspace

> ⚠️ **CRITICAL SECURITY WARNING** ⚠️
>
> **DO NOT USE WITH UNAPPROVED MODELS.** This tool provides LLMs with full access to entire codebases through its MCP server. Using Substrate/Flowspace with an unapproved model is equivalent to giving that model direct, unrestricted access to your codebase.
>
> **EXERCISE EXTREME CAUTION** when using the MCP server with tools like Claude Code or any other LLM-powered coding assistants. Only use models that have been explicitly approved by your organization's security team for handling sensitive code.
>
> By design, Substrate grants comprehensive codebase access to enable powerful context-aware features. Ensure you understand and accept these security implications before use.

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

## Prerequisites

Before installing Flowspace, ensure you have the following requirements:

### Required
- **Docker**: Flowspace requires Docker to be installed and available in your environment
  - Installation: [Get Docker](https://docs.docker.com/get-docker/)
  - Verify installation: `docker --version`

### AI Model Requirements
- **AI Foundry Models**: Flowspace integrates with various AI models for semantic analysis
  - Azure OpenAI (recommended): 
    - `text-embedding-3-small`
    - `model-router` (Provides access to GPT models for smart content)
  - API keys required
    > An AI Foundry endpoint has been setup for the ANZ Studio shared subscription, [go here to retrieve the key](https://ai.azure.com/foundryProject/overview?wsid=/subscriptions/418b6908-0c66-41f3-904d-59751b10b3d6/resourceGroups/rg-ise-anz-hve/providers/Microsoft.CognitiveServices/accounts/flowspace-ise-anz-resource/projects/flowspace-ise-anz&tid=16b3c013-d300-468d-ac64-7eda0820b6d3)

**Need to set up your own AI Foundry models?** See the [AI Foundry Setup Guide](docs/ai-foundry-setup.md) for detailed instructions including Bicep templates.

## Getting Started

### 1. Installing Flowspace

### Quick Install (Recommended)

```bash
curl -L https://aka.ms/InstallFlowspace | bash
```

### Install Pre-Release Version

To install the latest pre-release version (including beta releases):

```bash
curl -L https://aka.ms/InstallFlowspace | FLOWSPACE_PRE_RELEASE=true bash
```

For manual installation options and advanced configuration, see the [Installation Guide](docs/installation.md).


### 2. Initializing Flowspace

After installation, navigate to your project directory and initialize Flowspace:

```bash
# Navigate to your project
cd /path/to/your/project

# Initialize Flowspace (creates .flowspace folder with configuration)
flowspace init
```

This creates a `.flowspace` folder containing:
- Configuration file (config.yaml)
- Registry files for repository management (registry.yaml)

### 3. Configuring Models

Configure your AI models and API settings:

#### Setting Up API Keys 

.env File**
Create a `.env` file in your project root: (It may already have one...)
```env
AZURE_OPENAI_API_KEY=your-api-key-here
```

> ⚠️ **Security Note**: Never put API keys directly in the config file. Flowspace will reject configurations with embedded keys for security.

#### Model Configuration

Edit your Flowspace configuration to specify models:

Use the below examples:

**Embedding:**
```yaml
embedding:
  mode: "azure"
  azure:
    api_key: "${AZURE_OPENAI_API_KEY}"
    endpoint: "https://flowspace-ise-anz-resource.openai.azure.com/"
    model: "text-embedding-3-small"
```

**LLM:**
```yaml
llm:
  provider: "azure"
  api_key: "${AZURE_OPENAI_API_KEY}"
  base_url: "https://flowspace-ise-anz-resource.openai.azure.com/"
  azure_deployment_name: "model-router"
  model: "model-router" 

```

### 4. Configure Scan Paths

Customize what Flowspace analyzes:
- **Scan Paths**: Directories to include in analysis
- **Ignore Paths**: Directories to exclude (node_modules, .git, etc.)
- Remove default entries that don't apply to your project

## Your First Scan

### Running a Full Scan

Execute a complete semantic analysis of your codebase:

```bash
# Run comprehensive analysis with embeddings generation
flowspace full-scan
```

This process will:
1. Parse your codebase using AST and SCIP analysis
2. Generate semantic embeddings for all code elements
3. Build relationship graphs between files, classes, and methods
4. Create searchable vector indices
5. Generate intelligent summaries

**Note**: The first scan may take several minutes depending on codebase size.

### Watch Mode (Optional)

Keep your Flowspace index updated as you work:

```bash
# Enable watch mode to auto-update on file changes
flowspace full-scan --watch
```

## Querying Your Codebase

### Installing the MCP Server

Flowspace provides a Model Context Protocol (MCP) server for integration with LLM coding assistants:

#### Option 1: Manual VS Code Configuration

You can add it to VS Code by putting this in your `.vscode/mcp.json`:
```json
{
	"servers": {
		"flowspace": {
			"type": "stdio",
			"command": "flowspace",
			"args": [
				"mcp"
			]
		}
	},
	"inputs": []
}
```

#### Option 2: Using Command Palette

Add the MCP server directly through VS Code:

1. **Open Command Palette**: In VS Code, press `⌘+Shift+P` (Mac) / `Ctrl+Shift+P` (Windows/Linux)
2. **Search for MCP**: Type "MCP" and select "MCP: Add Server"
3. **Configure Flowspace**: 
   - **Type**: `stdio`
   - **Command**: `flowspace mcp`
   - **Name**: `flowspace`
   - **Where to install**: `workspace`

This will automatically add the server configuration to your MCP settings.

The MCP server enables:
- **Advanced querying and visualization**
- **Integration with Claude Code and other LLM assistants**
- **Real-time codebase context for AI agents**

> ⚠️ **Security Warning**: The MCP server provides full codebase access to connected LLMs. Only use with approved models that your organization's security team has vetted for handling sensitive code.

### CLI Queries and Syntax

Once your scan is complete, you can query your codebase using Flowspace's enhanced v2 query patterns:

#### Enhanced Query Patterns (v2)

```bash
# Class-specific method searches - Find methods in specific classes
flowspace query "method:Calculator.add"              # Specific method in specific class
flowspace query "method:UserService.authenticate"    # Authentication method
flowspace query "method:BaseService.*"               # All methods in a class (inheritance-aware)

# Smart file searches - Multiple ways to find files
flowspace query "file:config"                        # Any file named 'config' (any extension)
flowspace query "file:tests/"                        # All files in tests directory
flowspace query "file:test_*.py"                     # Auto-regex: all test_*.py files

# Simple node type queries
flowspace query "class:Calculator"                   # Find specific class
flowspace query "method:add"                         # Find any method named 'add'
flowspace query "function:main"                      # Find main function

# Natural language semantic search (auto-detected)
flowspace query "authentication and authorization logic"
flowspace query "database connection management"
flowspace query "error handling patterns"
```

#### Search Types

```bash
# Text search (exact matches)
flowspace query -T "Calculator"

# Regex search  
flowspace query -R "def calculate_.*\("

# Semantic search (uses embeddings)
flowspace query -E "user authentication logic"

# Smart auto-detection (default) - automatically chooses best search type
flowspace query "method:.*Repository"                # Auto-detects as regex
flowspace query "find all test methods"              # Auto-detects as semantic
```

#### Output Formats

```bash
# Table format for easy comparison
flowspace query "class:.*Repository" -o table

# Pretty-printed detailed view
flowspace query "method:Calculator.*" -o pretty

# Custom columns
flowspace query "config" --columns name,file_path,line_number

# Filter by node types
flowspace query "validation" --node-type method --node-type function
```

For comprehensive query examples and advanced patterns, see the [Advanced Query Guide](docs/advanced-queries.md).


#### Repository Management

```bash
# Add external repositories to your analysis
flowspace repo add <repository-url>

# List all registered repositories
flowspace repo list

# Remove repositories from registry
flowspace repo remove <repository-name>

# Clone repositories for analysis
flowspace clone <repository-url>
```


```

## Support

- **Documentation**: Available in the main repository
- **Issues**: [GitHub Issues](https://github.com/AI-Substrate/flowspace/issues)
- **Discussions**: [GitHub Discussions](https://github.com/AI-Substrate/flowspace/discussions)

---

© 2025 AI-Substrate. All rights reserved.
