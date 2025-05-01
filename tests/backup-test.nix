# Test for backup functionality with -b flag
{ nixpkgs, self, system, ... }:

let
  pkgs = nixpkgs.legacyPackages.${system};
  username = "backup-tester";

  # Create a test memory file
  memoryText = ''
    # Test Memory
    This is a test memory for backup functionality.
  '';

  # Create a test command file
  testCommand = pkgs.writeTextFile {
    name = "test-command.md";
    text = ''
      # Test Command
      This is a test command for backup functionality.
    '';
  };

  # Create a second test command file (for overwriting test)
  replacementCommand = pkgs.writeTextFile {
    name = "test-command.md";
    text = ''
      # Replacement Command
      This is a replacement command that should overwrite or backup the original.
    '';
  };
in {
  name = "claude-code-backup-test";

  nodes = {
    # Machine without backup flag
    machine-no-backup = { config, lib, pkgs, ... }: {
      imports = [ self.inputs.home-manager.nixosModules.home-manager ];

      users.users.${username} = {
        isNormalUser = true;
        home = "/home/${username}";
      };

      home-manager.useGlobalPkgs = true;
      home-manager.useUserPackages = true;
      home-manager.users.${username} = {
        imports = [ self.homeManagerModules.default ];
        home.stateVersion = "23.11";

        programs.claude-code = {
          enable = true;
          commands = [ testCommand ];
          memory.text = memoryText;
          forceClean = false;
        };
      };

      # Validation script
      environment.systemPackages = [
        (pkgs.writeShellScriptBin "setup-for-backup-test" ''
          set -e
          echo "Setting up files for backup test..."

          # Create a directory and ensure proper permissions
          mkdir -p /home/${username}/.claude/commands
          chmod -R 755 /home/${username}/.claude

          # Create original files
          echo "# Original command" > /home/${username}/.claude/commands/original.md
          echo "# Original memory" > /home/${username}/.claude/CLAUDE.md

          echo "✅ Setup complete"
        '')
      ];
    };

    # Machine with backup flag
    machine-with-backup = { config, lib, pkgs, ... }: {
      imports = [ self.inputs.home-manager.nixosModules.home-manager ];

      users.users.${username} = {
        isNormalUser = true;
        home = "/home/${username}";
      };

      home-manager.useGlobalPkgs = true;
      home-manager.useUserPackages = true;
      home-manager.backupExtension = "backup";
      home-manager.users.${username} = {
        imports = [ self.homeManagerModules.default ];
        home.stateVersion = "23.11";

        programs.claude-code = {
          enable = true;
          commands = [ replacementCommand ];
          memory.text = memoryText;
          forceClean = false;
        };
      };

      # Validation script
      environment.systemPackages = [
        (pkgs.writeShellScriptBin "validate-backup-files" ''
          set -e
          echo "Validating backup files..."

          # Check for backup files
          if [ ! -f /home/${username}/.claude/commands/original.md.backup ]; then
            echo "❌ Backup of original command file not found"
            exit 1
          fi

          if [ ! -f /home/${username}/.claude/CLAUDE.md.backup ]; then
            echo "❌ Backup of original memory file not found"
            exit 1
          fi

          # Check that new files also exist
          if [ ! -f /home/${username}/.claude/commands/test-command.md ]; then
            echo "❌ New command file not found"
            exit 1
          fi

          if ! grep -q "Test Memory" /home/${username}/.claude/CLAUDE.md; then
            echo "❌ New memory file missing or incorrect"
            exit 1
          fi

          echo "✅ All backup tests passed!"
        '')
      ];
    };

    # Machine with backup flag but forceClean = true (should delete rather than backup)
    machine-force-clean = { config, lib, pkgs, ... }: {
      imports = [ self.inputs.home-manager.nixosModules.home-manager ];

      users.users.${username} = {
        isNormalUser = true;
        home = "/home/${username}";
      };

      home-manager.useGlobalPkgs = true;
      home-manager.useUserPackages = true;
      home-manager.backupExtension = "backup";
      home-manager.users.${username} = {
        imports = [ self.homeManagerModules.default ];
        home.stateVersion = "23.11";

        programs.claude-code = {
          enable = true;
          commands = [ replacementCommand ];
          memory.text = memoryText;
          forceClean = true;
        };
      };

      # Validation script
      environment.systemPackages = [
        (pkgs.writeShellScriptBin "validate-force-clean" ''
          set -e
          echo "Validating forceClean behavior with backup extension..."

          # Check that backup files don't exist (should be deleted, not backed up)
          if [ -f /home/${username}/.claude/commands/original.md.backup ]; then
            echo "❌ Backup of original command file found (should have been deleted)"
            exit 1
          fi

          # Check that original files don't exist
          if [ -f /home/${username}/.claude/commands/original.md ]; then
            echo "❌ Original command file still exists (should have been deleted)"
            exit 1
          fi

          # Check that new files exist
          if [ ! -f /home/${username}/.claude/commands/test-command.md ]; then
            echo "❌ New command file not found"
            exit 1
          fi

          if ! grep -q "Test Memory" /home/${username}/.claude/CLAUDE.md; then
            echo "❌ New memory file missing or incorrect"
            exit 1
          fi

          echo "✅ All forceClean tests passed!"
        '')
      ];
    };
  };

  testScript = ''
    # Setup initial files on the machine that will test -b functionality
    machine-no-backup.wait_for_unit("multi-user.target")
    machine-no-backup.succeed("setup-for-backup-test")

    # Test backup functionality
    machine-with-backup.wait_for_unit("multi-user.target")
    machine-with-backup.succeed("validate-backup-files")

    # Test forceClean overrides backup functionality
    machine-force-clean.wait_for_unit("multi-user.target")
    machine-force-clean.succeed("validate-force-clean")
  '';
}
