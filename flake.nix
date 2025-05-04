{
  description = "Nix home-manager module for Claude Code configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      home-manager,
      ...
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        packages.default = self.packages.${system}.claude-nix;

        packages.claude-nix = pkgs.callPackage ./lib/package.nix { };

        devShells.default = pkgs.mkShell { buildInputs = with pkgs; [ nixpkgs-fmt ]; };
      }
    )
    // {
      homeManagerModules.default = import ./lib/claude-code.nix;
      homeManagerModules.claude-code = self.homeManagerModules.default;
    };
}
