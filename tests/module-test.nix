# NixOS module test for claude-nix
# This is a golden test that verifies the NixOS module works by inspecting actual files

{ pkgs ? import <nixpkgs> { }, lib ? pkgs.lib
, claudeNix ? import ../. { inherit pkgs; } }:

let
  # Create a virtual machine test using Python driver
  nixosTest = import (pkgs.path + "/nixos/tests/make-test-python.nix") ({
    name = "claude-nix-nixos-test";

    nodes.machine = { pkgs, ... }: {
      imports = [ claudeNix.nixosModules.default ];

      # Basic system configuration
      virtualisation.memorySize = 1024;
      virtualisation.diskSize = 2048;
      users.users.testuser = {
        isNormalUser = true;
        home = "/home/testuser";
        password = "password";
        # Define shell to ensure consistent environment
        shell = pkgs.bash;
      };

      # Configure claude-code
      programs.claude-code = {
        enable = true;
        user = "testuser";
        commands = [ ./test-command.md ];
        memory.text = ''
          # Test memory file
          - Follow instructions carefully
          - Keep responses concise
        '';
        mcpServers = {
          test-server = {
            command = "echo";
            args = [ "test server" ];
          };
        };
        forceClean = true;
      };

      # Make sure jq is available for tests
      environment.systemPackages = [ pkgs.jq ];
    };

    # Test script that verifies correct files are created with proper permissions
    testScript = ''
      # Start machine and wait for login to be available
      machine.start()
      machine.wait_for_unit("multi-user.target")

      # Verify that required directories and files exist
      with subtest("Check directories exist"):
          machine.succeed("test -d /home/testuser/.claude")
          machine.succeed("test -d /home/testuser/.claude/commands")

      with subtest("Check directory permissions"):
          # Test .claude directory permissions
          dir_perms = machine.succeed("stat -c %a /home/testuser/.claude").strip()
          assert dir_perms == "755", f"Expected .claude directory permissions to be 755, got {dir_perms}"
          
          # Test commands directory permissions
          cmd_dir_perms = machine.succeed("stat -c %a /home/testuser/.claude/commands").strip()
          assert cmd_dir_perms == "755", f"Expected commands directory permissions to be 755, got {cmd_dir_perms}"

      with subtest("Check command file installation"):
          # Check command file exists
          machine.succeed("test -f /home/testuser/.claude/commands/test-command.md")
          
          # Test command file permissions
          cmd_perms = machine.succeed("stat -c %a /home/testuser/.claude/commands/test-command.md").strip()
          assert cmd_perms == "644", f"Expected command file permissions to be 644, got {cmd_perms}"
          
          # Check content of command file
          content = machine.succeed("cat /home/testuser/.claude/commands/test-command.md")
          assert "Test Command" in content, "Command file is missing expected content"
          assert "Testing the claude-nix module" in content, "Command file is missing expected description"

      with subtest("Check memory file installation"):
          # Check memory file exists
          machine.succeed("test -f /home/testuser/.claude/CLAUDE.md")
          
          # Test memory file permissions
          mem_perms = machine.succeed("stat -c %a /home/testuser/.claude/CLAUDE.md").strip()
          assert mem_perms == "644", f"Expected memory file permissions to be 644, got {mem_perms}"
          
          # Check content of memory file
          mem_content = machine.succeed("cat /home/testuser/.claude/CLAUDE.md")
          assert "Test memory file" in mem_content, "Memory file is missing expected content"
          assert "Keep responses concise" in mem_content, "Memory file is missing expected content"

      with subtest("Check MCP servers config"):
          # Check MCP config file exists
          machine.succeed("test -f /home/testuser/.claude.json")
          
          # Test config file permissions
          config_perms = machine.succeed("stat -c %a /home/testuser/.claude.json").strip()
          assert config_perms == "644", f"Expected config file permissions to be 644, got {config_perms}"
          
          # Verify JSON content using jq
          has_mcpservers = machine.succeed("jq 'has(\"mcpServers\")' /home/testuser/.claude.json").strip()
          assert has_mcpservers == "true", "JSON file missing mcpServers section"
          
          has_testserver = machine.succeed("jq '.mcpServers | has(\"test-server\")' /home/testuser/.claude.json").strip()
          assert has_testserver == "true", "JSON file missing test-server configuration"
          
          cmd_value = machine.succeed("jq -r '.mcpServers.\"test-server\".command' /home/testuser/.claude.json").strip()
          assert cmd_value == "echo", f"Expected command to be 'echo', got '{cmd_value}'"

      # Log all file contents for inspection
      machine.log("=== Command file content ===")
      machine.succeed("cat /home/testuser/.claude/commands/test-command.md")

      machine.log("=== Memory file content ===")
      machine.succeed("cat /home/testuser/.claude/CLAUDE.md")

      machine.log("=== MCP servers config content ===")
      machine.succeed("cat /home/testuser/.claude.json")

      # Copy files to an archive for inspection
      machine.succeed(
          "mkdir -p /tmp/claude-nix-output && "
          "cp -r /home/testuser/.claude /tmp/claude-nix-output/ && "
          "cp /home/testuser/.claude.json /tmp/claude-nix-output/ && "
          "tar -czf /tmp/claude-nix-files.tar.gz -C /tmp claude-nix-output"
      )

      # Copy archive to host for inspection 
      machine.copy_from_vm("/tmp/claude-nix-files.tar.gz", "claude-nix-files.tar.gz")
    '';
  });

  # Create a test derivation that preserves test output and the file archive
  testDrv = pkgs.runCommand "claude-nix-nixos-golden-test" {
    nativeBuildInputs = [ pkgs.gnutar pkgs.gzip ];
  } ''
    mkdir -p $out/nix-support $out/golden-files

    # Run the test
    echo "Running NixOS test..."
    if ${nixosTest.driver}/bin/nixos-test-driver; then
      echo "Claude-nix NixOS module test passed!"
      
      # Copy logs and files
      cp ${nixosTest.driver}/logs/machine.log $out/machine.log
      
      # Extract the archive of generated files if it exists
      if [ -f ${nixosTest.driver}/claude-nix-files.tar.gz ]; then
        mkdir -p $out/golden-files
        tar -xzf ${nixosTest.driver}/claude-nix-files.tar.gz -C $out/golden-files
        echo "Generated files extracted to $out/golden-files"
      else
        echo "Warning: No generated files archive found"
      fi
      
      # Create build products for Hydra
      echo "report claude-nix-test $out/machine.log" > $out/nix-support/hydra-build-products
    else
      echo "Claude-nix NixOS module test failed!"
      exit 1
    fi
  '';
in testDrv
