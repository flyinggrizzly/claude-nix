{ config, lib, pkgs, ... }:

with lib;

let cfg = config.programs.claude-code;
in {
  options.programs.claude-code = {
    enable = mkEnableOption "Claude Code configuration";

    commands = mkOption {
      type = types.listOf types.path;
      default = [ ];
      description =
        "List of file paths to be copied to ~/.claude/commands/. These take precedence over files from commandsDir.";
    };

    commandsDir = mkOption {
      type = types.nullOr types.path;
      default = null;
      description =
        "Directory containing command files (markdown) to be copied to ~/.claude/commands/. Individual commands specified in the commands option will take precedence over files with the same name from this directory.";
    };

    package = mkOption {
      type = types.nullOr types.package;
      default = pkgs.claude-code;
      defaultText = literalExpression "pkgs.claude-code";
      description =
        "The Claude Code package to use. Set to null to not install any package.";
    };

    memory = mkOption {
      default = { };
      description =
        "Configuration for Claude's memory file at ~/.claude/CLAUDE.md";
      type = types.submodule {
        options = {
          text = mkOption {
            type = types.nullOr types.str;
            default = null;
            description =
              "String content to write to ~/.claude/CLAUDE.md. If both text and source are provided, source takes precedence.";
          };

          source = mkOption {
            type = types.nullOr types.path;
            default = null;
            description =
              "Path to a file whose content will be copied to ~/.claude/CLAUDE.md. Takes precedence over text if both are provided.";
          };
        };
      };
    };

    mcpServers = mkOption {
      type = types.attrsOf types.anything;
      default = { };
      description = ''
        An attrset of MCP server configurations to merge into ~/.claude.json.
        The entire attrset will be merged into the JSON file as the "mcpServers" field.
        Supports all JSON data types including nested objects, arrays, strings, numbers, and booleans.
        Claude needs to be able to write to this file, so it is not directly managed by Nix.
      '';
      example = literalExpression ''
        {
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
              GITHUB_PERSONAL_ACCESS_TOKEN = "MY-TOKEN";
            };
          };
        }
      '';
    };

    forceClean = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Whether to forcibly clean out existing files before applying configuration.
        When true, the module will remove all files in ~/.claude/commands/ 
        and delete ~/.claude/CLAUDE.md before copying/creating new files,
        regardless of whether a backup extension is provided.

        If home-manager is invoked with the backup extension flag (-b) and forceClean is false,
        existing files will be backed up with that extension instead of being overwritten.
        For example, running `home-manager switch -b bak` will cause 
        ~/.claude/commands/foo.md to be moved to ~/.claude/commands/foo.md.bak before
        the new version is installed.
      '';
    };
  };

  config = mkIf cfg.enable {
    assertions = [{
      assertion = cfg.memory.source == null || cfg.memory.text == null;
      message = "Set only one of memory.source or memory.text, not both";
    }];

    home.packages = lib.optional (cfg.package != null) cfg.package;

    home.activation.setupClaudeCommands =
      lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        CLAUDE_DIR="$HOME/.claude"
        CLAUDE_COMMANDS_DIR="$CLAUDE_DIR/commands"

        # Create the directory if it doesn't exist with proper permissions
        $DRY_RUN_CMD mkdir -p "$CLAUDE_COMMANDS_DIR"
        # Ensure the directory is usable by forcing permissions
        $DRY_RUN_CMD install -d -m 0755 "$CLAUDE_COMMANDS_DIR"

        # Handle backup extension if provided through home-manager -b flag
        if [ -n "$HOME_MANAGER_BACKUP_EXT" ]; then
          BACKUP_EXT="$HOME_MANAGER_BACKUP_EXT"
          echo "Using backup extension: .$BACKUP_EXT"
        fi

        # Clean commands directory if forceClean is enabled and we have commands or commandsDir
        ${if cfg.forceClean
        && (cfg.commands != [ ] || cfg.commandsDir != null) then ''
          echo "Cleaning commands directory..."
          # When forceClean is true, always delete the files regardless of backup extension
          $DRY_RUN_CMD rm -f "$CLAUDE_COMMANDS_DIR"/*
        '' else
          ""}

        # First, copy markdown files from commandsDir if specified
        ${if cfg.commandsDir != null then ''
          # Find all .md files and copy them using install to set permissions properly
          for CMD_FILE in $(find "${cfg.commandsDir}" -type f -name "*.md"); do
            DEST_FILE="$CLAUDE_COMMANDS_DIR/$(basename "$CMD_FILE")"
            # Check if the destination file exists and backup extension is set
            if [ -f "$DEST_FILE" ] && [ -n "$BACKUP_EXT" ]; then
              $DRY_RUN_CMD mv "$DEST_FILE" "$DEST_FILE.$BACKUP_EXT"
            fi
            $DRY_RUN_CMD install -m 0644 "$CMD_FILE" "$DEST_FILE"
          done
        '' else ''
          # No commandsDir specified, skipping
        ''}

        ${concatMapStringsSep "\n" (commandPath:
          let
            filename = builtins.baseNameOf commandPath;
            parts = builtins.match "^[^-]+-(.*)$" filename;
            finalName =
              if parts == null then filename else builtins.elemAt parts 0;
          in ''
            DEST_FILE="$CLAUDE_COMMANDS_DIR/${finalName}"
            # Check if the destination file exists and backup extension is set
            if [ -f "$DEST_FILE" ] && [ -n "$BACKUP_EXT" ]; then
              $DRY_RUN_CMD mv "$DEST_FILE" "$DEST_FILE.$BACKUP_EXT"
            fi
            $DRY_RUN_CMD install -m 0644 "${commandPath}" "$DEST_FILE"
          '') cfg.commands}
      '';

    home.activation.setupClaudeMemory =
      lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        CLAUDE_DIR="$HOME/.claude"
        CLAUDE_MEMORY_FILE="$CLAUDE_DIR/CLAUDE.md"

        $DRY_RUN_CMD mkdir -p "$CLAUDE_DIR"
        $DRY_RUN_CMD install -d -m 0755 "$CLAUDE_DIR"

        # Handle backup extension if provided through home-manager -b flag
        if [ -n "$HOME_MANAGER_BACKUP_EXT" ]; then
          BACKUP_EXT="$HOME_MANAGER_BACKUP_EXT"
        fi

        # Clean memory file if forceClean is enabled and we have memory configuration
        ${if cfg.forceClean
        && (cfg.memory.source != null || cfg.memory.text != null) then ''
          echo "Cleaning memory file..."
          # When forceClean is true, always delete the memory file regardless of backup extension
          $DRY_RUN_CMD rm -f "$CLAUDE_MEMORY_FILE"
        '' else ''
          # forceClean not enabled or no memory specified, skipping cleanup
        ''}

        # Handle memory configuration
        ${if cfg.memory.source != null then ''
          # Check if the memory file exists and backup extension is set
          if [ -f "$CLAUDE_MEMORY_FILE" ] && [ -n "$BACKUP_EXT" ]; then
            $DRY_RUN_CMD mv "$CLAUDE_MEMORY_FILE" "$CLAUDE_MEMORY_FILE.$BACKUP_EXT"
          fi
          $DRY_RUN_CMD install -m 0644 "${cfg.memory.source}" "$CLAUDE_MEMORY_FILE"
        '' else if cfg.memory.text != null then ''
                    # Check if the memory file exists and backup extension is set
                    if [ -f "$CLAUDE_MEMORY_FILE" ] && [ -n "$BACKUP_EXT" ]; then
                      $DRY_RUN_CMD mv "$CLAUDE_MEMORY_FILE" "$CLAUDE_MEMORY_FILE.$BACKUP_EXT"
                    fi
                    # Use a temporary file and install to ensure proper permissions
                    $DRY_RUN_CMD cat > "$TMPDIR/claude_memory_temp.md" << 'EOF'
          ${cfg.memory.text}
          EOF
                    $DRY_RUN_CMD install -m 0644 "$TMPDIR/claude_memory_temp.md" "$CLAUDE_MEMORY_FILE"
                    $DRY_RUN_CMD rm -f "$TMPDIR/claude_memory_temp.md"
        '' else ''
          # Neither source nor text was set, do nothing
        ''}
      '';

    home.activation.setupClaudeMcpServers =
      lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        CLAUDE_DIR="$HOME/.claude"
        CLAUDE_CONFIG_FILE="$HOME/.claude.json"

        # Create directory if it doesn't exist with proper permissions
        $DRY_RUN_CMD mkdir -p "$CLAUDE_DIR"
        # Ensure the directory is usable by forcing permissions
        $DRY_RUN_CMD install -d -m 0755 "$CLAUDE_DIR"

        # If mcpServers configuration is not empty
        ${if cfg.mcpServers != { } then ''
                    # Check if the config file exists
                    if [ -f "$CLAUDE_CONFIG_FILE" ]; then
                      # Read existing JSON config
                      EXISTING_CONFIG=$($DRY_RUN_CMD cat "$CLAUDE_CONFIG_FILE" || echo "{}")
                    else
                      # Create a new config with empty object
                      EXISTING_CONFIG="{}"
                    fi

                    # Create a temporary file with the MCP server configuration
                    NEW_MCP_CONFIG=$(cat <<'EOF'
          ${builtins.toJSON { mcpServers = cfg.mcpServers; }}
          EOF
                    )

                    # Merge the configurations (preserving existing content and adding/updating mcpServers)
                    MERGED_CONFIG=$($DRY_RUN_CMD ${pkgs.jq}/bin/jq -s '.[0] * .[1]' <(echo "$EXISTING_CONFIG") <(echo "$NEW_MCP_CONFIG"))

                    # Write the merged configuration to a temp file first
                    $DRY_RUN_CMD echo "$MERGED_CONFIG" > "$TMPDIR/claude_config_temp.json"
                    
                    # Use install to set permissions and copy the file
                    $DRY_RUN_CMD install -m 0644 "$TMPDIR/claude_config_temp.json" "$CLAUDE_CONFIG_FILE"
                    $DRY_RUN_CMD rm -f "$TMPDIR/claude_config_temp.json"
        '' else ''
          # No MCP servers configured, do nothing
        ''}
      '';
  };
}
