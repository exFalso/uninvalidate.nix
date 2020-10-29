let
  pkgs = import ./nixpkgs.nix {};
  pkgs-src = import ./nixpkgs-src.nix;
in pkgs.mkShell {
  NIX_PATH="nixpkgs=${pkgs-src}";
  
  buildInputs = [
    pkgs.nix
  ];
}
