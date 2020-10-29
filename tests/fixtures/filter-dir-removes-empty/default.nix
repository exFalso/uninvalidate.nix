let
  pkgs = import ../../nix/nixpkgs.nix {};
  ui = import ../../../uninvalidate.nix {};
  transform = source: ui.toPath (ui.filterOutDirectories (ui.fromPath source));
in pkgs.runCommand ("test-${builtins.baseNameOf ./.}") {} ''
  set -euo pipefail
  local original=${./original}
  local expected=${./expected}
  local result_original=${transform ./original}
  local result_expected=${transform ./expected}
  ! diff -r "$original" "$result_original" > /dev/null
  diff -r "$expected" "$result_original"
  diff -r "$expected" "$result_expected"
  [[ "$result_original" == "$result_expected" ]]
  touch $out
''
