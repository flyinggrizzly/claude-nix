# Claude Nix

>[!CAUTION]
> Claude [currently has a bug where it can't read symlinked files](https://github.com/anthropics/claude-code/issues/764),
> so this module **does not manage its files using Nix's standard add-to-store-and-symlink approach. Instead it adds
> them to the store, and then uses an activation script to **copy** the files to the right location. The main
> consequence of this is that if you don't set the `forceClean` flag, removing e.g. a command from your config *won't
> remove it from the produced config*.
>
> `forceClean` exists to work around this, by cleaning up all commands *before* the current ones are copied in, **but it
> is not able to preserve any non-Nix-tracked commands**, so use it with caution, and create backups.

A Nix flake that provides a home-manager module for configuring Claude Code.

## Features

- Install the Claude Code CLI package (optional)
- Configure command files in `~/.claude/commands/` by passing a directory and/or a list of individual files
- Manage Claude memory in `~/.claude/CLAUDE.md`
- Configure MCP servers in `~/.claude.json`
- Support for standalone home-manager
- Follows the `-b <backup-ext>` flag

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

and a simple config:

```nix
{ ... }:
{
  config = {
    imports = [
      inputs.claude-nix.homeManagerModules.claude-code
    ];

    programs.claude-code = {
      enable = true;
      commandsDir = ./command-directory;
      commands = [ ./path/to/extra/command.md ];
      memory.source = ./my/claude.md;
      mcpServers = {
        github = {
          command = "docker";
          args = ["run" "-i" "--rm" "-e" "GITHUB_PERSONAL_ACCESS_TOKEN" "ghcr.io/github/github-mcp-server"];
          env = {
            # Don't store this as plain text. Use like, agenix or sops-nix or sumthing
            GITHUB_PERSONAL_ACCESS_TOKEN = "TOKEN";
          };
        };
      };
    };
  }
}
```

## Configuration Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enable` | boolean | `false` | Enable Claude Code configuration |
| `commands` | list of paths | `[]` | Individual command files to copy to `~/.claude/commands/` |
| `commandsDir` | path | `null` | Directory of markdown files to copy as commands |
| `package` | package or null | `pkgs.claude-code` | Claude Code package to install (or null to not install) |
| `forceClean` | boolean | `false` | Clean existing files before applying configuration |
| `skipBackup` | boolean | `false` | Skips backing up files even if the -`b <backup-ext> option is set` |
| `memory.text` | string | `null` | Content to write to `~/.claude/CLAUDE.md` |
| `memory.source` | path | `null` | File to copy to `~/.claude/CLAUDE.md` (takes precedence over `text`) |
| `mcpServers` | attrset | `{}` | MCP server configurations to merge into `~/.claude.json` |


## Rationale and approach

Claude [currently has a bug where it can't read symlinked files](https://github.com/anthropics/claude-code/issues/764),
which is why this flake uses the activation scripts to copy files into place (once the bug is resolved, the flake's API
can remain the same but we can replace the scripts with actual nix config setup).

Additionally, Claude writes to `~/.claude.json` so it can't be directly managed by Nix.

## Development

```bash
# Format code
nix develop
nixpkgs-fmt .

# Run tests
nix flake check
```

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details. Claude itself has
proprietary licensing, plus nix and home-manager have their own shit. Go look it up.
