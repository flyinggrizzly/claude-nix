{ config, lib, pkgs, ... }:

with lib;

let cfg = config.programs.claude-code;
in {
  options.programs.claude-code = {
    enable = mkEnableOption "Claude Code configuration";

    commands = mkOption {
      type = types.listOf types.path;
      default = [ ];
      description = "List of file paths to be copied to ~/.claude/commands/";
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
  };

  config = mkIf cfg.enable {
    home.packages = lib.optional (cfg.package != null) cfg.package;

    home.activation.setupClaudeCommands =
      lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        CLAUDE_DIR="$HOME/.claude"
        CLAUDE_COMMANDS_DIR="$CLAUDE_DIR/commands"

        $DRY_RUN_CMD mkdir -p "$CLAUDE_COMMANDS_DIR"
        ${concatMapStringsSep "\n" (commandPath: ''
          $DRY_RUN_CMD cp -f "${commandPath}" "$CLAUDE_COMMANDS_DIR/"
        '') cfg.commands}
      '';

    home.activation.setupClaudeMemory =
      lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        CLAUDE_DIR="$HOME/.claude"
        CLAUDE_MEMORY_FILE="$CLAUDE_DIR/CLAUDE.md"

        # Create the directory if it doesn't exist
        $DRY_RUN_CMD mkdir -p "$CLAUDE_DIR"

        # Handle memory configuration
        ${if cfg.memory.source != null then ''
          # Copy from source file
          $DRY_RUN_CMD cp -f "${cfg.memory.source}" "$CLAUDE_MEMORY_FILE"
        '' else if cfg.memory.text != null then ''
                    # Write text content to file
                    $DRY_RUN_CMD cat > "$CLAUDE_MEMORY_FILE" << 'EOF'
          ${cfg.memory.text}
          EOF
        '' else ''
          # Neither source nor text was set, do nothing
        ''}
      '';

    home.activation.setupClaudeMcpServers =
      lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        CLAUDE_DIR="$HOME/.claude"
        CLAUDE_CONFIG_FILE="$HOME/.claude.json"

        # Create directory if it doesn't exist
        $DRY_RUN_CMD mkdir -p "$CLAUDE_DIR"

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

                    # Write the merged configuration back to ~/.claude.json
                    $DRY_RUN_CMD echo "$MERGED_CONFIG" > "$CLAUDE_CONFIG_FILE"
        '' else ''
          # No MCP servers configured, do nothing
        ''}
      '';
  };
}
