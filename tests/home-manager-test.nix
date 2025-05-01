# Home Manager test for claude-nix
# This is a golden test that verifies the home-manager module works

{ pkgs ? import <nixpkgs> { }
, lib ? pkgs.lib
, home-manager ? null
, claudeNix ? import ../. { inherit pkgs; }
}:

let
  # Import home-manager for testing
  homePkgs = if home-manager == null 
    then (import (builtins.fetchTarball {
      url = "https://github.com/nix-community/home-manager/archive/master.tar.gz";
    }) {})
    else home-manager;

  # Create a home-manager configuration
  hmConfig = homePkgs.lib.homeManagerConfiguration {
    pkgs = pkgs;
    modules = [
      claudeNix.homeManagerModules.default
      {
        home = {
          username = "testuser";
          homeDirectory = "/home/testuser";
          stateVersion = "23.11";
        };
        
        programs.claude-code = {
          enable = true;
          commands = [ ./test-command.md ];
          memory.text = ''
            # Test memory
            - Keep responses concise
            - Follow instructions carefully
          '';
          mcpServers = {
            test = {
              command = "echo";
              args = [ "test" ];
            };
          };
          # Use forceClean to ensure clean test state
          forceClean = true;
        };
      }
    ];
  };
  
  # Build the full home configuration
  home = hmConfig.activationPackage;
  
  # Create a test derivation
  testDrv = pkgs.runCommand "claude-nix-home-manager-test" { 
    nativeBuildInputs = with pkgs; [ bash jq ];
  } ''
    mkdir -p $out/nix-support
    
    # Set up a fake $HOME to run activation and inspect results
    export HOME=$TMPDIR/home
    mkdir -p $HOME
    
    echo "Running home-manager activation..."
    ${home}/activate

    echo "Inspecting generated files..."
    
    # Check directories exist and have correct permissions
    if [ ! -d "$HOME/.claude" ]; then
      echo "ERROR: .claude directory not created"
      exit 1
    fi
    
    if [ ! -d "$HOME/.claude/commands" ]; then
      echo "ERROR: .claude/commands directory not created"
      exit 1
    fi
    
    CLAUDE_DIR_PERMS=$(stat -c %a "$HOME/.claude")
    if [ "$CLAUDE_DIR_PERMS" != "755" ]; then
      echo "ERROR: .claude directory has incorrect permissions: $CLAUDE_DIR_PERMS (expected 755)"
      exit 1
    fi
    
    COMMANDS_DIR_PERMS=$(stat -c %a "$HOME/.claude/commands")
    if [ "$COMMANDS_DIR_PERMS" != "755" ]; then
      echo "ERROR: .claude/commands directory has incorrect permissions: $COMMANDS_DIR_PERMS (expected 755)"
      exit 1
    fi
    
    # Check test command file was installed properly
    if [ ! -f "$HOME/.claude/commands/test-command.md" ]; then
      echo "ERROR: test-command.md not installed"
      exit 1
    fi
    
    CMD_PERMS=$(stat -c %a "$HOME/.claude/commands/test-command.md")
    if [ "$CMD_PERMS" != "644" ]; then
      echo "ERROR: test-command.md has incorrect permissions: $CMD_PERMS (expected 644)"
      exit 1
    fi
    
    # Verify file content
    if ! grep -q "Test Command" "$HOME/.claude/commands/test-command.md"; then
      echo "ERROR: test-command.md has incorrect content"
      cat "$HOME/.claude/commands/test-command.md"
      exit 1
    fi
    
    # Check memory file was created properly
    if [ ! -f "$HOME/.claude/CLAUDE.md" ]; then
      echo "ERROR: CLAUDE.md not created"
      exit 1
    fi
    
    MEM_PERMS=$(stat -c %a "$HOME/.claude/CLAUDE.md")
    if [ "$MEM_PERMS" != "644" ]; then
      echo "ERROR: CLAUDE.md has incorrect permissions: $MEM_PERMS (expected 644)"
      exit 1
    fi
    
    # Verify memory file content
    if ! grep -q "Test memory" "$HOME/.claude/CLAUDE.md"; then
      echo "ERROR: CLAUDE.md has incorrect content"
      cat "$HOME/.claude/CLAUDE.md"
      exit 1
    fi
    
    # Check MCP servers config file
    if [ ! -f "$HOME/.claude.json" ]; then
      echo "ERROR: .claude.json not created"
      exit 1
    fi
    
    # Verify JSON content
    if ! jq -e '.mcpServers.test.command == "echo"' "$HOME/.claude.json" > /dev/null; then
      echo "ERROR: .claude.json has incorrect content"
      cat "$HOME/.claude.json"
      exit 1
    fi
    
    # Test passed - copy relevant files to output
    mkdir -p $out/golden-files
    cp -r $HOME/.claude $out/golden-files/
    cp $HOME/.claude.json $out/golden-files/
    
    echo "Claude-nix home-manager golden test passed!" > $out/result
    echo "report claude-nix-home-manager-test $out/result" > $out/nix-support/hydra-build-products
  '';
in testDrv
