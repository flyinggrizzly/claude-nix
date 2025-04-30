{ config, lib, pkgs, ... }:

{
  # In real usage, you would import from the flake
  # Example: inputs.claude-nix.nixosModules.default
  imports = [ ];

  programs.claude-code = {
    enable = true;
    user = "yourusername";
    commands = [ ./tests/test-command.md ];
    # Optional: Use a custom package or set to null to not install one
    # package = pkgs.claude-code;

    # Optional: Configure Claude's memory file
    memory = {
      # Either use text to provide content directly
      # text = ''
      #   # Claude Memory
      #   This is information that Claude will remember across sessions.
      # '';

      # Or use source to copy from a file
      # source = ./claude-memory.md;

      # Note: If both text and source are provided, source takes precedence
    };

    # Optional: Configure MCP servers to be merged into ~/.claude.json
    mcpServers = {
      # github = {
      #   command = "docker";
      #   args = [
      #     "run"
      #     "-i"
      #     "--rm"
      #     "-e"
      #     "GITHUB_PERSONAL_ACCESS_TOKEN"
      #     "ghcr.io/github/github-mcp-server"
      #   ];
      #   env = {
      #     GITHUB_PERSONAL_ACCESS_TOKEN = "\${input:github_token}";
      #   };
      # };
    };
  };

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
  };
}
