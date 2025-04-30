# Claude Nix

A Nix flake that provides modules for configuring Claude Code in both home-manager and NixOS.

## Features

- Install the Claude Code CLI package (optional)
- Configure command files in `~/.claude/commands/`
- Manage Claude memory in `~/.claude/CLAUDE.md`
- Configure MCP servers in `~/.claude.json`
- Support standalone home-manager and NixOS

## Quick Start

Add this flake to your inputs:

```nix
{
  inputs = {
    # ...
    claude-nix.url = "github:flyinggrizzly/claude-nix";
  };
}
```

## Configuration Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enable` | boolean | `false` | Enable Claude Code configuration |
| `commands` | list of paths | `[]` | Individual command files to copy to `~/.claude/commands/` |
| `commandsDir` | path | `null` | Directory of markdown files to copy as commands |
| `package` | package or null | `pkgs.claude-code` | Claude Code package to install (or null to not install) |
| `preClean` | boolean | `false` | Clean existing files before applying configuration |
| `memory.text` | string | `null` | Content to write to `~/.claude/CLAUDE.md` |
| `memory.source` | path | `null` | File to copy to `~/.claude/CLAUDE.md` (takes precedence over `text`) |
| `mcpServers` | attrset | `{}` | MCP server configurations to merge into `~/.claude.json` |
| `user` | string | (NixOS only) | The user to install Claude Code for |


### Configuration

```nix
{
  imports = [
    inputs.claude-nix.homeManagerModules.default
    # Or for NixOS: inputs.claude-nix.nixosModules.default
  ];

  programs.claude-code = {
    enable = true;
    # For NixOS, specify user: user = "yourusername";
    
    # Copy individual command files
    commands = [ ./path/to/command.md ];
    
    # Copy all markdown files from a directory
    commandsDir = ./command-directory;
    
    # Set memory content directly
    memory.text = ''
      # Claude Memory
      This is information Claude will remember across sessions.
    '';
    
    # Configure MCP servers (like GitHub)
    mcpServers = {
      github = {
        command = "docker";
        args = ["run" "-i" "--rm" "-e" "GITHUB_PERSONAL_ACCESS_TOKEN" "ghcr.io/github/github-mcp-server"];
        env = {
          GITHUB_PERSONAL_ACCESS_TOKEN = "\${input:github_token}";
        };
      };
    };
  };
}
```

## Rationale and approach

Claude [currently has a bug where it can't read symlinked files](https://github.com/anthropics/claude-code/issues/764),
which is why this flake uses the activation scripts to copy files into place (once the bug is resolved, the flake's API
can remain the same but we can replace the scripts with actual nix config setup).

Additionall, Claude writes to `~/.claude.json` so it can't be directly managed by Nix.

## Development

```bash
# Format code
nix develop
nixpkgs-fmt .

# Run tests
nix flake check
```

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
