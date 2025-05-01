{
  description = "Nix module for Claude Code configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, flake-utils, home-manager, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let pkgs = nixpkgs.legacyPackages.${system};
      in {
        packages.default = self.packages.${system}.claude-nix;

        packages.claude-nix = pkgs.callPackage ./lib/package.nix { };

        devShells.default =
          pkgs.mkShell { buildInputs = with pkgs; [ nixpkgs-fmt ]; };
      }) // {
        homeManagerModules.default = import ./lib/claude-code.nix;
        homeManagerModules.claude-code = self.homeManagerModules.default;
        nixosModules.default = { config, lib, pkgs, ... }:
          with lib;
          let cfg = config.programs.claude-code;
          in {
            options.programs.claude-code = {
              enable = mkEnableOption "Claude Code configuration";

              commands = mkOption {
                type = types.listOf types.path;
                default = [ ];
                description =
                  "List of file paths to be copied to ~/.claude/commands/. These take precedence over files from commandsDir.";
              };

              commandsDir = mkOption {
                type = types.nullOr types.path;
                default = null;
                description =
                  "Directory containing command files (markdown) to be copied to ~/.claude/commands/. Individual commands specified in the commands option will take precedence over files with the same name from this directory.";
              };

              user = mkOption {
                type = types.str;
                description = "The user to install Claude Code for";
              };

              package = mkOption {
                type = types.nullOr types.package;
                default = pkgs.claude-code;
                defaultText = literalExpression "pkgs.claude-code";
                description =
                  "The Claude Code package to use. Set to null to not install any package.";
              };

              memory = mkOption {
                default = { };
                description =
                  "Configuration for Claude's memory file at ~/.claude/CLAUDE.md";
                type = types.submodule {
                  options = {
                    text = mkOption {
                      type = types.nullOr types.str;
                      default = null;
                      description =
                        "String content to write to ~/.claude/CLAUDE.md. If both text and source are provided, source takes precedence.";
                    };

                    source = mkOption {
                      type = types.nullOr types.path;
                      default = null;
                      description =
                        "Path to a file whose content will be copied to ~/.claude/CLAUDE.md. Takes precedence over text if both are provided.";
                    };
                  };
                };
              };

              mcpServers = mkOption {
                type = types.attrsOf types.anything;
                default = { };
                description = ''
                  An attrset of MCP server configurations to merge into ~/.claude.json.
                  The entire attrset will be merged into the JSON file as the "mcpServers" field.
                  Supports all JSON data types including nested objects, arrays, strings, numbers, and booleans.
                  Claude needs to be able to write to this file, so it is not directly managed by Nix.
                '';
                example = literalExpression ''
                  {
                    github = {
                      command = "docker";
                      args = [
                        "run"
                        "-i"
                        "--rm"
                        "-e"
                        "GITHUB_PERSONAL_ACCESS_TOKEN"
                        "ghcr.io/github/github-mcp-server"
                      ];
                      env = {
                        GITHUB_PERSONAL_ACCESS_TOKEN = "''${input:github_token}";
                      };
                    };
                  }
                '';
              };

              preClean = mkOption {
                type = types.bool;
                default = false;
                description = ''
                  Whether to clean out existing files before applying configuration.
                  When true, the module will remove all files in ~/.claude/commands/ 
                  and delete ~/.claude/CLAUDE.md before copying/creating new files.
                '';
              };
            };

            config = mkIf cfg.enable {
              imports = [ home-manager.nixosModules.home-manager ];
              home-manager.users.${cfg.user} = {
                imports = [ self.homeManagerModules.default ];
                programs.claude-code = {
                  enable = true;
                  commands = cfg.commands;
                  commandsDir = cfg.commandsDir;
                  package = cfg.package;
                  memory = cfg.memory;
                  mcpServers = cfg.mcpServers;
                  preClean = cfg.preClean;
                };
              };
            };
          };

        nixosModules.claude-code = self.nixosModules.default;
      };
}
