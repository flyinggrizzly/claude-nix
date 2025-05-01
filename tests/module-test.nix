{ type }:

let
  nixosSystem = import <nixpkgs/nixos> {
    configuration = { pkgs, lib, ... }: {
      imports = [ ../lib/package.nix ../flake.nix ];

      # Configure just enough for a minimal system
      boot.loader.grub.enable = false;
      fileSystems."/" = {
        device = "none";
        fsType = "tmpfs";
      };
      users.users.testuser = {
        isNormalUser = true;
        home = "/home/testuser";
      };

      system.stateVersion = "23.11";
    };
  };

  homeManagerLib = import (builtins.fetchTarball {
    url = "https://github.com/nix-community/home-manager/archive/master.tar.gz";
    sha256 =
      "1gsh49m4xvw8qzq2vi8v7fg67vqc1a0wj9zwf0s3ihhyg71226ci"; # Update with current hash
  }) { };

  pkgs = import <nixpkgs> { };
  lib = pkgs.lib;

  # Helper function to create a home-manager configuration
  mkHomeConfig = { extraConfig ? { }, memory ? { }, commands ? [ ]
    , commandsDir ? null, mcpServers ? { }, forceClean ? false }:
    if type == "standalone" then
      homeManagerLib.homeManagerConfiguration {
        inherit pkgs;
        modules = [
          ../lib/claude-code.nix
          {
            home = {
              username = "testuser";
              homeDirectory = "/home/testuser";
              stateVersion = "23.11";
            };

            programs.claude-code = {
              enable = true;
              inherit memory commands commandsDir mcpServers forceClean;
            } // extraConfig;
          }
        ];
      }
    else
      nixosSystem.config.home-manager.users.testuser;

  runTest = name: homeConfig: action:
    let
      testScript = ''
        import os
        import pathlib
        import json
        import subprocess

        # Helper functions for tests
        def file_exists(path):
            return os.path.exists(path)
            
        def file_content(path):
            with open(path, 'r') as f:
                return f.read()
                
        def file_is_backup(path, expected_backup_ext):
            return path.endswith('.' + expected_backup_ext)
            
        def json_content(path):
            with open(path, 'r') as f:
                return json.load(f)

        # Setup home directory structure for tests
        os.makedirs('/home/testuser/.claude/commands', exist_ok=True)

        # Run the specific test action
        ${action}
      '';
    in pkgs.nixosTest {
      name = name;
      nodes.machine = { ... }: {
        imports = [
          (if type == "nixos" then {
            imports = [ ../flake.nix ];

            programs.claude-code = {
              enable = true;
              user = "testuser";
              inherit (homeConfig.config.programs.claude-code)
                memory commands commandsDir mcpServers forceClean;
            };
          } else
            { })
        ];

        virtualisation.memorySize = 1024;
        virtualisation.diskSize = 1024;

        users.users.testuser = {
          isNormalUser = true;
          home = "/home/testuser";
        };
      };

      testScript = testScript;
    };

  # Test cases
  tests = {
    baseline = runTest "baseline" (mkHomeConfig {
      memory.source = ../tests/test-command.md;
      commands = [ ../tests/test-command.md ];
      commandsDir = ../tests/commands;
      mcpServers = {
        test = {
          command = "test";
          args = [ "arg1" "arg2" ];
        };
      };
    }) ''
      # Test memory.source creates the CLAUDE.md file
      machine.succeed("test -f /home/testuser/.claude/CLAUDE.md")
      content = machine.succeed("cat /home/testuser/.claude/CLAUDE.md")
      assert "Test Command" in content, "CLAUDE.md does not contain expected content"

      # Test commandsDir copies contents to ~/.claude/commands
      machine.succeed("test -f /home/testuser/.claude/commands/command_1.md")
      machine.succeed("test -f /home/testuser/.claude/commands/command_2.md")

      # Test commands copies each item to ~/.claude/commands
      command_content = machine.succeed("cat /home/testuser/.claude/commands/test-command.md")
      assert "Test Command" in command_content, "Command file does not contain expected content"

      # Test mcpServers merges into ~/.claude.json
      machine.succeed("test -f /home/testuser/.claude.json")
      json_str = machine.succeed("cat /home/testuser/.claude.json")
      assert '"test"' in json_str, "~/.claude.json does not contain test server config"
      assert '"arg1"' in json_str, "~/.claude.json does not contain expected args"
    '';

    conflictingMemoryOptions = runTest "conflicting-memory-options"
      (mkHomeConfig {
        memory = {
          source = ../tests/test-command.md;
          text = "This should cause an error";
        };
      }) ''
        # This test is expected to fail with an assertion error
        machine.fail("test -f /home/testuser/.claude/CLAUDE.md")
      '';

    backupFlag = runTest "backup-flag" (mkHomeConfig {
      memory.source = ../tests/test-command.md;
      commands = [ ../tests/test-command.md ];
    }) ''
      # First create the files
      machine.succeed("mkdir -p /home/testuser/.claude/commands")
      machine.succeed("echo 'Original content' > /home/testuser/.claude/CLAUDE.md")
      machine.succeed("echo 'Original command' > /home/testuser/.claude/commands/test-command.md")

      # Run home-manager with backup flag
      machine.succeed("HOME_MANAGER_BACKUP_EXT=bak")

      # Apply configuration
      # (home-manager application happens during nixos-test running)

      # Check if backup files were created
      machine.succeed("test -f /home/testuser/.claude/CLAUDE.md.bak")
      machine.succeed("test -f /home/testuser/.claude/commands/test-command.md.bak")

      # Verify original content in backups
      orig_content = machine.succeed("cat /home/testuser/.claude/CLAUDE.md.bak")
      assert "Original content" in orig_content, "Backup file does not contain original content"

      # Verify new content in place
      new_content = machine.succeed("cat /home/testuser/.claude/CLAUDE.md")
      assert "Test Command" in new_content, "New file does not contain expected content"
    '';

    forceClean = runTest "force-clean" (mkHomeConfig {
      memory.source = ../tests/test-command.md;
      commands = [ ../tests/test-command.md ];
      forceClean = true;
    }) ''
      # First create the files
      machine.succeed("mkdir -p /home/testuser/.claude/commands")
      machine.succeed("echo 'Original content' > /home/testuser/.claude/CLAUDE.md")
      machine.succeed("echo 'Original command' > /home/testuser/.claude/commands/test-command.md")
      machine.succeed("echo 'Extra command' > /home/testuser/.claude/commands/extra-command.md")

      # Set backup extension (should be ignored due to forceClean)
      machine.succeed("HOME_MANAGER_BACKUP_EXT=bak")

      # Apply configuration
      # (home-manager application happens during nixos-test running)

      # Check that backup files were NOT created (due to forceClean)
      machine.fail("test -f /home/testuser/.claude/CLAUDE.md.bak")
      machine.fail("test -f /home/testuser/.claude/commands/test-command.md.bak")

      # Check that extra files were removed
      machine.fail("test -f /home/testuser/.claude/commands/extra-command.md")

      # Verify new content in place
      new_content = machine.succeed("cat /home/testuser/.claude/CLAUDE.md")
      assert "Test Command" in new_content, "New file does not contain expected content"
    '';
  };
in {
  inherit tests;

  # Run all tests by default
  all = pkgs.linkFarm "all-tests" (lib.mapAttrsToList (name: test: {
    inherit name;
    path = test;
  }) tests);
}
