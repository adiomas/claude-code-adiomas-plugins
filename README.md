# Adiomas Claude Code Plugins

Personal collection of Claude Code plugins.

## Installation

### Add Marketplace

```bash
claude plugin marketplace add adiomas/claude-code-adiomas-plugins
```

### Install Plugins

```bash
# List available plugins
claude plugin marketplace list

# Install a plugin
claude plugin install <plugin-name>@adiomas-plugins
```

## Available Plugins

| Plugin | Description |
|--------|-------------|
| [autonomous-dev](./autonomous-dev/) | Universal autonomous development system - describe what you want, Claude handles the rest |

## Updating Plugins

```bash
# Update marketplace cache
claude plugin marketplace update adiomas-plugins

# Update specific plugin
claude plugin update autonomous-dev@adiomas-plugins
```

## For Development

```bash
# Clone the repo
git clone https://github.com/adiomas/claude-code-adiomas-plugins.git

# Test locally
claude --plugin-dir /path/to/claude-code-adiomas-plugins/autonomous-dev
```

## Adding New Plugins

1. Create plugin directory: `mkdir my-plugin`
2. Add plugin structure (see [autonomous-dev](./autonomous-dev/) for example)
3. Update `.claude-plugin/marketplace.json`:
   ```json
   {
     "plugins": [
       ...existing plugins...,
       {
         "name": "my-plugin",
         "description": "Description",
         "source": "./my-plugin"
       }
     ]
   }
   ```
4. Commit and push
5. Run `claude plugin marketplace update adiomas-plugins`

## License

MIT
