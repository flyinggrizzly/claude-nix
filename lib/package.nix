{ lib, stdenv }:

stdenv.mkDerivation {
  pname = "claude-nix";
  version = "0.1.0";

  src = ../.;

  dontBuild = true;

  installPhase = ''
    mkdir -p $out/share/doc/claude-nix
    cp -f $src/readme.md $out/share/doc/claude-nix/readme.md
    cp -f $src/LICENSE $out/share/doc/claude-nix/LICENSE || true
  '';

  meta = with lib; {
    description = "Nix module for Claude Code configuration";
    license = licenses.mit;
    platforms = platforms.all;
    maintainers = [ ];
    mainProgram = "claude";
  };
}
