let
  pkgs = import ../../nix/nixpkgs.nix {};
  ui = import ../../../uninvalidate.nix {};
in pkgs.runCommand ("test-${builtins.baseNameOf ./.}") {} ''
  set -euo pipefail
  local original=${./original}
  local ui=${ui.toPath (ui.fromPath ./original)}
  diff -r "$original" "$ui"
  touch $out
''
