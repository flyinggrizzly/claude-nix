{ pkgs, module }:

let
  # Create a simple test command file
  testCommand = pkgs.writeTextFile {
    name = "test-command.md";
    text = ''
      # Test command
      echo "Hello from the test command"
    '';
    executable = true;
  };

  # Create a very simple test that doesn't use home-manager
  testContent = ''
    # Check the module path
    if [ ! -f ${toString module} ]; then
      echo "ERROR: Module file does not exist"
      exit 1
    fi

    # Verify the module contains the correct program option
    if ! grep -q "programs.claude-code" ${toString module}; then
      echo "ERROR: Module doesn't contain programs.claude-code option"
      exit 1
    fi

    # Verify the module contains the correct package
    if ! grep -q "home.packages.*claude-code" ${toString module}; then
      echo "ERROR: Module doesn't install claude-code package"
      exit 1
    fi

    # Verify the module contains the command directory setup
    if ! grep -q ".claude/commands" ${toString module}; then
      echo "ERROR: Module doesn't reference .claude/commands directory"
      exit 1
    fi

    # All checks passed
    echo "All tests passed!" > $out
  '';

  # Create a test derivation
  testDrv = pkgs.runCommand "claude-code-module-test" {
    buildInputs = [ pkgs.bash pkgs.gnugrep ];
  } testContent;

in testDrv
