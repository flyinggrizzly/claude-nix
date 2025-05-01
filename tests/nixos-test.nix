# This is a test configuration for NixOS with home-manager
{ nixpkgs, self, system, ... }:

let
  pkgs = nixpkgs.legacyPackages.${system};
  username = "nixos-tester";
  
  # Create a test memory source file
  memorySource = pkgs.writeTextFile {
    name = "claude-memory.md";
    text = ''
      # NixOS Test Memory
      This is a test memory for Claude Code on NixOS.
    '';
  };
in
{
  name = "claude-code-nixos-test";
  
  nodes.machine = { config, lib, pkgs, ... }: {
    imports = [
      # Import the module from the flake
      self.nixosModules.default
    ];

    # Basic NixOS configuration
    users.users.${username} = {
      isNormalUser = true;
      home = "/home/${username}";
    };

    # Configure Claude Code through NixOS module
    programs.claude-code = {
      enable = true;
      user = username;
      commands = [ ../tests/test-command.md ];
      commandsDir = ../tests;
      forceClean = true;
      
      memory.source = memorySource;
      
      mcpServers = {
        nixostest = {
          command = "echo";
          args = ["NixOS Test MCP Server"];
          env = {
            TEST_VAR = "test_value";
          };
        };
      };
    };

    # Add simple test validation script
    environment.systemPackages = [
      (pkgs.writeShellScriptBin "validate-nixos-claude-config" ''
        set -e
        echo "Validating Claude Code NixOS configuration..."
        
        # Check if command file exists
        if [ ! -f /home/${username}/.claude/commands/test-command.md ]; then
          echo "❌ Test command not found"
          exit 1
        fi
        
        # Check memory file
        if ! grep -q "NixOS Test Memory" /home/${username}/.claude/CLAUDE.md; then
          echo "❌ Memory file missing or incorrect"
          exit 1
        fi
        
        # Check MCP servers config
        if ! grep -q "nixostest" /home/${username}/.claude.json; then
          echo "❌ MCP servers configuration missing or incorrect"
          exit 1
        fi
        
        if ! grep -q "TEST_VAR" /home/${username}/.claude.json; then
          echo "❌ MCP server environment variables missing or incorrect"
          exit 1
        fi
        
        echo "✅ All NixOS tests passed!"
      '')
    ];

    # For automated testing
    system.build.validateConfig = pkgs.runCommand "validate-nixos-claude-config" {} ''
      mkdir -p $out/bin
      echo "#!/bin/sh" > $out/bin/validate
      echo "exec validate-nixos-claude-config" >> $out/bin/validate
      chmod +x $out/bin/validate
    '';
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")
    machine.succeed("validate-nixos-claude-config")
  '';
}