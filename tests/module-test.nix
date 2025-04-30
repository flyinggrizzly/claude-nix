# Non-VM test for the modules
{ nixpkgs, self, system, ... }:

let
  pkgs = nixpkgs.legacyPackages.${system};
  
  # Create a simple test command file
  testCommand = pkgs.writeTextFile {
    name = "test-command.md";
    text = ''
      # Test command
      echo "Hello from the test command"
    '';
  };
  
  moduleFile = ./. + "/../lib/claude-code.nix";
  
  # Create a very simple test that doesn't use home-manager
  testContent = ''
    # Skip file existence check as it's handled by Nix
    # We know the file exists since this test is being built
    
    # Check the module content by inspecting a copy
    mkdir -p $out
    cp ${moduleFile} $out/module.nix

    # Verify the module contains the correct program option
    if ! grep -q "programs.claude-code" $out/module.nix; then
      echo "ERROR: Module doesn't contain programs.claude-code option"
      exit 1
    fi

    # Verify the module contains the correct package
    if ! grep -q "home.packages" $out/module.nix; then
      echo "ERROR: Module doesn't install packages"
      exit 1
    fi

    # Verify the module contains the command directory setup
    if ! grep -q ".claude/commands" $out/module.nix; then
      echo "ERROR: Module doesn't reference .claude/commands directory"
      exit 1
    fi
    
    # Verify key config options exist
    if ! grep -q "preClean" $out/module.nix; then
      echo "ERROR: Module doesn't contain preClean option"
      exit 1
    fi
    
    if ! grep -q "commandsDir" $out/module.nix; then
      echo "ERROR: Module doesn't contain commandsDir option"
      exit 1
    fi
    
    # Verify memory config
    if ! grep -q "memory.source" $out/module.nix; then
      echo "ERROR: Module doesn't contain memory.source option"
      exit 1
    fi
    
    if ! grep -q "memory.text" $out/module.nix; then
      echo "ERROR: Module doesn't contain memory.text option"
      exit 1
    fi
    
    # Verify mcpServers config
    if ! grep -q "mcpServers" $out/module.nix; then
      echo "ERROR: Module doesn't contain mcpServers option"
      exit 1
    fi

    # All checks passed
    echo "All tests passed!" > $out/result.txt
  '';

in pkgs.runCommand "claude-code-module-test" {
  buildInputs = [ pkgs.bash pkgs.gnugrep ];
} testContent