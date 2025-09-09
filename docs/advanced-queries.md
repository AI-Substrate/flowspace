# Advanced Query Guide

Flowspace provides powerful code search capabilities with enhanced v2 patterns including class-specific method searches, inheritance-aware searches, and smart regex auto-detection. The query command automatically detects the search type from your pattern and provides flexible output formatting.

## Query Command Overview

The query command provides multiple search methods:
- **Natural Language**: Uses embeddings for semantic search
- **Class-Specific Methods**: Find methods in specific classes
- **Inheritance-Aware**: Find base methods AND all implementations  
- **Enhanced File Search**: Multiple ways to find files
- **Smart Regex**: Auto-detects regex patterns
- **Text Search**: Exact text matching

## Enhanced Search Patterns (v2)

### Class-Specific Method Searches

Find methods in specific classes using the `method:Class.method` pattern:

```bash
# Find Calculator.add method specifically (not add() in other classes)
flowspace query "method:Calculator.add"

# Find private method in specific class
flowspace query "method:SmartContentService._process_element"

# Find constructor in specific class
flowspace query "method:RepoService.__init__"

# Find all methods in a specific class
flowspace query "method:Calculator.*"
```

### Inheritance-Aware Searches

Find base methods AND all implementations in derived classes:

```bash
# Find base method and all overrides in derived classes
flowspace query "method:BaseService.process"
# Results: BaseService.process, TextService.process, ImageService.process, etc.

# Find interface method and all implementations
flowspace query "method:ILlmRepository.generate_smart_content"
# Results: Base interface + all Repository implementations

# Find all abstract method implementations
flowspace query "method:AbstractParser.*"
```

### Enhanced File Searches

Multiple ways to find files with improved pattern matching:

```bash
# Basename search - finds any file named 'config' (any extension, any directory)
flowspace query "file:config"
# Results: config.py, src/config.yaml, tests/config.json

# Partial path search
flowspace query "file:tests/test_auth"
# Results: tests/test_auth.py, tests/test_authentication.py

# Directory search - all files in a directory
flowspace query "file:src/utils/"
# Results: All files directly in src/utils/ directory

# Extension-based search
flowspace query "file:*.yaml"
# Results: All YAML files in the codebase
```

### Smart Regex Auto-Detection

Flowspace automatically switches to regex mode when it detects regex patterns:

```bash
# These automatically become regex searches (no -R flag needed):
flowspace query "class:.*LLM.*"        # All LLM classes
flowspace query "class:.*Repository"   # All Repository classes  
flowspace query "method:.+test.*"      # All test methods
flowspace query "file:test_.*\.py"     # All test_*.py files
flowspace query "function:calculate_.*" # All calculate functions
```

### Simple Node Type Queries

Direct searches for specific code elements:

```bash
# Find specific classes
flowspace query "class:Calculator"
flowspace query "class:UserService"

# Find specific methods
flowspace query "method:add"
flowspace query "method:authenticate"

# Find specific functions
flowspace query "function:main"
flowspace query "function:validate_input"

# Find specific files
flowspace query "file:server.py"
flowspace query "file:config.json"
```

## Search Types and Flags

### Natural Language Search (Default)
Uses embeddings for semantic understanding:

```bash
# Auto-detected as natural language
flowspace query "calculate sum of numbers"
flowspace query "authentication and authorization logic"
flowspace query "database connection management"
flowspace query "error handling for API calls"
```

### Text Search (-T flag)
Exact text matching:

```bash
# Find exact text matches
flowspace query -T "Calculator"
flowspace query -T "def process_data"
flowspace query -T "import requests"
```

### Regex Search (-R flag)
Regular expression matching:

```bash
# Explicit regex search
flowspace query -R "def calculate_.*\("
flowspace query -R "class.*Repository.*:"
flowspace query -R "import\s+\w+\s+as\s+\w+"
```

### Embedding/Semantic Search (-E flag)
Force semantic search:

```bash
# Explicit semantic search
flowspace query -E "user authentication logic"
flowspace query -E "data validation patterns"
flowspace query -E "async operations and concurrency"
```

## Advanced Filtering and Output

### Node Type Filtering

Filter results by specific node types:

```bash
# Filter by single node type
flowspace query "validation" --node-type method
flowspace query "config" --node-type file
flowspace query "Parser" --node-type class

# Filter by multiple node types
flowspace query "test" --node-type method --node-type function
flowspace query "utils" --node-type file --node-type class
```

### Output Formats

Choose different output formats for better readability:

```bash
# Table format (great for comparisons)
flowspace query "method:Calculator.*" -o table

# Pretty-printed format (detailed view)
flowspace query "class:.*Repository" -o pretty

# JSON format (for programmatic use)
flowspace query "file:config" -o json

# Custom columns (specify what to show)
flowspace query "Parser" --columns name,file_path,line_number
flowspace query "test" --columns name,node_type,summary
```

### Advanced Examples

Complex queries combining multiple features:

```bash
# Find all test methods in specific directory
flowspace query "method:test_.*" --node-type method | grep "tests/"

# Find all Repository classes with table output
flowspace query "class:.*Repository" -o table

# Find configuration files with detailed info
flowspace query "file:config" --columns name,file_path,size,modified

# Search for authentication methods across the codebase
flowspace query "method:.*auth.*" -o pretty

# Find all async methods
flowspace query "method:async.*" --node-type method

# Complex inheritance search with output formatting
flowspace query "method:BaseService.*" --node-type method -o table
```

## Integration with Reports

Generate detailed reports from query results:

```bash
# Generate documentation for query results
flowspace query "class:Calculator" --interesting-output DocumentCode

# Create architectural analysis reports
flowspace query "method:BaseService.*" --interesting-output ArchitectureAnalysis

# Generate test coverage reports
flowspace query "method:test_.*" --interesting-output TestCoverage
```

## Query Performance Tips

### Optimize Your Queries

1. **Use Specific Patterns**: `method:Calculator.add` is faster than `method:add`
2. **Filter Early**: Use `--node-type` to reduce result sets
3. **Choose Appropriate Search Type**: Use `-T` for exact matches, `-E` for semantic
4. **Limit Results**: Use output formatting to focus on relevant information

### Best Practices

```bash
# Good: Specific class method search
flowspace query "method:UserService.authenticate"

# Less optimal: Generic method search
flowspace query "method:authenticate"

# Good: Directory-specific file search
flowspace query "file:src/models/"

# Less optimal: Global filename search
flowspace query "file:model"

# Good: Filtered semantic search
flowspace query -E "database operations" --node-type method

# Less optimal: Unfiltered broad search
flowspace query -E "database"
```

## Error Handling and Troubleshooting

### Common Issues

1. **No Results Found**: Try broader search patterns or different search types
2. **Too Many Results**: Use filtering or more specific patterns
3. **Regex Errors**: Verify regex syntax when using `-R` flag
4. **Performance Issues**: Use more specific queries or add filters

### Debugging Queries

```bash
# Test different search types
flowspace query -T "exact text"     # Text search
flowspace query -R "regex.*pattern" # Regex search  
flowspace query -E "semantic query" # Embedding search

# Verify node types exist
flowspace list-node-ids | grep "Calculator"

# Check available node types
flowspace analyze-relationships | grep "node_type"
```

## Query Types Reference

| Pattern Type | Example | Description |
|--------------|---------|-------------|
| `method:Class.method` | `method:Calculator.add` | Find specific method in specific class |
| `method:BaseClass.*` | `method:BaseService.*` | Find all methods in class (inheritance-aware) |
| `class:ClassName` | `class:Calculator` | Find specific class |
| `class:.*Pattern` | `class:.*Repository` | Find classes matching pattern (auto-regex) |
| `file:filename` | `file:config` | Find files by basename |
| `file:path/` | `file:src/utils/` | Find all files in directory |
| `function:name` | `function:main` | Find specific function |
| Natural language | `"authentication logic"` | Semantic search using embeddings |

## Integration with NetworkX Query System

For even more advanced queries, Flowspace integrates with NetworkX for graph-based searches:

```bash
# Graph relationship queries
flowspace analyze-relationships --focus-node "Calculator"

# Network analysis
flowspace view-relationships --node-type class

# Advanced graph queries (see NetworkX documentation)
flowspace query --graph-query "nodes with degree > 5"
```

For more information on graph-based queries, see the NetworkX Query System documentation.

---

**Next Steps:**
- Try the basic patterns in the main README
- Experiment with different output formats
- Combine queries with other Flowspace commands
- Explore the MCP integration for IDE-based querying
