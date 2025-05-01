# This is a test configuration for standalone home-manager
{ nixpkgs, self, system, ... }:

let
  pkgs = nixpkgs.legacyPackages.${system};
  username = "tester";

  # Create a test memory file
  memoryText = ''
    # Test Memory
    This is a test memory for Claude Code.
  '';

  # Create a test command file
  testCommand = pkgs.writeTextFile {
    name = "extra-test-command.md";
    text = ''
      # Test Command
      This is an extra test command for Claude Code.
    '';
  };
in {
  name = "claude-code-home-manager-test";

  nodes.machine = { config, lib, pkgs, ... }: {
    imports = [
      # Import home-manager NixOS module
      self.inputs.home-manager.nixosModules.home-manager
    ];

    # Basic NixOS configuration
    users.users.${username} = {
      isNormalUser = true;
      home = "/home/${username}";
    };

    # Configure home-manager
    home-manager.useGlobalPkgs = true;
    home-manager.useUserPackages = true;
    home-manager.users.${username} = {
      imports = [ self.homeManagerModules.default ];
      home.stateVersion = "23.11";

      programs.claude-code = {
        enable = true;
        commands = [ testCommand ../tests/test-command.md ];
        commandsDir = ../tests;
        forceClean = true;

        memory.text = memoryText;

        mcpServers = {
          testserver = {
            command = "echo";
            args = [ "Test MCP Server" ];
          };
        };
      };
    };

    # Add simple test validation script
    environment.systemPackages = [
      (pkgs.writeShellScriptBin "validate-claude-config" ''
        set -e
        echo "Validating Claude Code configuration..."

        # Check if command files exist
        if [ ! -f /home/${username}/.claude/commands/extra-test-command.md ]; then
          echo "❌ Extra test command not found"
          exit 1
        fi

        if [ ! -f /home/${username}/.claude/commands/test-command.md ]; then
          echo "❌ Test command not found"
          exit 1
        fi

        # Check memory file
        if ! grep -q "Test Memory" /home/${username}/.claude/CLAUDE.md; then
          echo "❌ Memory file missing or incorrect"
          exit 1
        fi

        # Check MCP servers config
        if ! grep -q "testserver" /home/${username}/.claude.json; then
          echo "❌ MCP servers configuration missing or incorrect"
          exit 1
        fi

        echo "✅ All tests passed!"
      '')
    ];

    # For automated testing
    system.build.validateConfig =
      pkgs.runCommand "validate-claude-config" { } ''
        mkdir -p $out/bin
        echo "#!/bin/sh" > $out/bin/validate
        echo "exec validate-claude-config" >> $out/bin/validate
        chmod +x $out/bin/validate
      '';
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")
    machine.succeed("validate-claude-config")
  '';
}
