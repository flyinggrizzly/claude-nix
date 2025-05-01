# Simple test for file overwriting
{ nixpkgs, self, system, ... }:

let
  pkgs = nixpkgs.legacyPackages.${system};

  # Create a test command file
  testCommand = pkgs.writeTextFile {
    name = "test-command-v1.md";
    text = ''
      # Test Command - Version 1
      This is the first version of the test command.
    '';
  };

  # Create an updated version of the same command
  updatedCommand = pkgs.writeTextFile {
    name = "test-command-v2.md";
    text = ''
      # Test Command - Version 2
      This is the updated version of the test command.
    '';
  };

  # Create a test script to verify permissions and overwriting works
  testScript = ''
    # Set up test directories
    mkdir -p $out/test-run-1 $out/test-run-2

    # Create initial Claude directory structure with restricted permissions
    mkdir -p $out/test-run-1/.claude/commands

    # Copy first version of the command
    cp ${testCommand} $out/test-run-1/.claude/commands/test-command.md

    # Make the file read-only
    chmod 444 $out/test-run-1/.claude/commands/test-command.md
    # Make the directory read-only
    chmod 555 $out/test-run-1/.claude/commands
    chmod 555 $out/test-run-1/.claude

    # Verify first version was installed
    if ! grep -q "Version 1" $out/test-run-1/.claude/commands/test-command.md; then
      echo "❌ First version of test command not installed correctly"
      exit 1
    fi

    # Create a copy of claude-code.nix for testing
    cp ${self}/lib/claude-code.nix $out/claude-code.nix

    # Create a temporary shell script that simulates the copy process
    cat > $out/test-copy.sh << 'EOF'
    #!/bin/sh
    set -e

    # Set up paths similar to the module
    CLAUDE_DIR="$1/.claude"
    CLAUDE_COMMANDS_DIR="$CLAUDE_DIR/commands"

    # Create the directory with proper permissions
    mkdir -p "$CLAUDE_COMMANDS_DIR"
    install -d -m 0755 "$CLAUDE_COMMANDS_DIR"

    # Use install to copy the file
    install -m 0644 "$2" "$CLAUDE_COMMANDS_DIR/test-command.md"

    # Verify result
    if grep -q "Version 2" "$CLAUDE_COMMANDS_DIR/test-command.md"; then
      echo "✅ File was successfully overwritten with Version 2!"
      echo "success" > "$1/result.txt"
    else
      echo "❌ Failed to overwrite file!"
      exit 1
    fi
    EOF

    chmod +x $out/test-copy.sh

    # Run the test script
    $out/test-copy.sh $out/test-run-2 ${updatedCommand}

    # Verify the test passed
    if [ -f $out/test-run-2/result.txt ] && grep -q "success" $out/test-run-2/result.txt; then
      echo "✅ Rewrite test passed! Files were successfully overwritten." > $out/result
    else
      echo "❌ Rewrite test failed!" > $out/result
      exit 1
    fi
  '';

in pkgs.runCommand "claude-code-rewrite-test" {
  buildInputs = [ pkgs.bash pkgs.coreutils pkgs.gnugrep ];
} testScript
