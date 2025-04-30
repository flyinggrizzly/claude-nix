# Claude Nix

A Nix flake that provides modules for configuring Claude Code in both home-manager and NixOS.

## Features

- Installs the Claude Code CLI package (optionally)
- Copies command files to `~/.claude/commands/` directory individually or from a directory
- Manages Claude memory file at `~/.claude/CLAUDE.md`
- Configures MCP servers in `~/.claude.json` 
- Supports cleaning existing files before applying new configuration
- Ensures files are actual copies, not symlinks
- Works with both standalone home-manager and NixOS with home-manager

## Usage

Add this flake to your inputs:

```nix
{
  inputs = {
    # ...
    claude-code.url = "github:yourusername/claude-code"; # Update with actual repository
  };
}
```

### Home Manager Usage

```nix
{
  imports = [
    inputs.claude-code.homeManagerModules.default
  ];

  programs.claude-code = {
    enable = true;
    commands = [
      # List of paths to command files you want to use with Claude
      ./path/to/command1.sh
      ./path/to/command2.md
    ];
    
    # Optional: Specify a directory containing Markdown command files to copy
    # commandsDir = ./commands-directory;
    
    # Optional: Specify a custom Claude Code package or set to null
    # package = pkgs.claude-code;  # Default
    # package = null;  # Don't install any package
    
    # Optional: Clean existing files before applying configuration
    preClean = true;
    
    # Optional: Configure Claude's memory file at ~/.claude/CLAUDE.md
    memory = {
      # Either use text to provide content directly
      text = ''
        # Claude Memory File
        
        This is information that Claude will remember across sessions.
      '';
      
      # Or use source to copy from a file (takes precedence if both are specified)
      # source = ./claude-memory.md;
      
      # Note: If both text and source are provided, source takes precedence
    };
    
    # Optional: Configure MCP servers to be merged into ~/.claude.json
    mcpServers = {
      github = {
        command = "docker";
        args = [
          "run"
          "-i"
          "--rm"
          "-e"
          "GITHUB_PERSONAL_ACCESS_TOKEN"
          "ghcr.io/github/github-mcp-server"
        ];
        env = {
          GITHUB_PERSONAL_ACCESS_TOKEN = "\${input:github_token}";
        };
      };
    };
  };
}
```

### NixOS Usage

```nix
{
  imports = [
    inputs.claude-code.nixosModules.default
  ];
  
  # This requires home-manager as a NixOS module
  programs.claude-code = {
    enable = true;
    user = "yourusername"; # The user to install Claude Code for
    commands = [
      # List of paths to command files you want to use with Claude
      ./path/to/command1.sh
      ./path/to/command2.md
    ];
    
    # Optional: Specify a directory containing Markdown command files to copy
    # commandsDir = ./commands-directory;
    
    # Optional: Specify a custom Claude Code package or set to null
    # package = pkgs.claude-code;  # Default
    # package = null;  # Don't install any package
    
    # Optional: Clean existing files before applying configuration
    preClean = true;
    
    # Optional: Configure Claude's memory file at ~/.claude/CLAUDE.md
    memory = {
      # Either use text to provide content directly
      text = ''
        # Claude Memory File
        
        This is information that Claude will remember across sessions.
      '';
      
      # Or use source to copy from a file (takes precedence if both are specified)
      # source = ./claude-memory.md;
      
      # Note: If both text and source are provided, source takes precedence
    };
    
    # Optional: Configure MCP servers to be merged into ~/.claude.json
    mcpServers = {
      github = {
        command = "docker";
        args = [
          "run"
          "-i"
          "--rm"
          "-e"
          "GITHUB_PERSONAL_ACCESS_TOKEN"
          "ghcr.io/github/github-mcp-server"
        ];
        env = {
          GITHUB_PERSONAL_ACCESS_TOKEN = "\${input:github_token}";
        };
      };
    };
  };
}
```

## Notes

- Claude writes history to `~/.claude.json` which can't be directly managed by Nix
- The module ensures all command files are copied (not symlinked) as required by Claude Code
- Command files are copied during the home-manager activation phase, after the writeBoundary
- For the NixOS module, home-manager must be configured as a NixOS module

## Development

To format the code:

```
nix develop
nixpkgs-fmt .
```

To run tests:

```
nix flake check
```

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.