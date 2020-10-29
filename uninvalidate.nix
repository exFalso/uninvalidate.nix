# These functions work with "uninvalidation" (ui) derivations containing:
#   /base  - file containing a single base directory path. This is the
#            original "source" /nix/store directory.
#   /paths - file containing paths relative to base.
# 1. cp files in .ui into an invalidated derivation
# 2. calculate nix hash of directory
# 3. create fixed output (uninvalidated) derivation with hash + cp -r of invalidated dir
# 4. import
# 5. ????
# 6. profit
{ debug ? false
}:
let
  pkgs = import <nixpkgs> {};

  debugBash = if debug then "true" else "false";
  debugTrace = if debug then (object: builtins.trace "${object}" object) else (object: object);

  # Produces a store path containing:
  #   /hash    - nix hash of contents
  #   /src.tar - tarred up contents
  toInvalidated = ui: pkgs.runCommand "invalidated" {} ''
    set -euo pipefail
    mkdir -p tmp
    local base=$(cat "${ui}/base")
    while read path
    do
      local source="$base/$path"
      local destination="tmp/$path"
      if [[ -d "$source" ]]
      then
        mkdir -p "$destination"
      else
        mkdir -p $(dirname "$destination")
        cp "$source" "$destination"
      fi
    done < "${ui}/paths"

    mkdir -p "$out"
    ${pkgs.nix}/bin/nix-hash --type sha256 tmp | tr -d '[:space:]' > "$out/hash"
    (cd tmp && tar -cf "$out/src.tar" .)
  '';

  toUninvalidatedNix = invalidated: debugTrace (pkgs.runCommand "uninvalidated" {} ''
    set -euo pipefail
    mkdir -p $out
    cp "${invalidated}/src.tar" "$out/src.tar"
    cat > "$out/default.nix" << EOF
    let
      pkgs = import <nixpkgs> {};
      sha256 = "${builtins.readFile "${invalidated}/hash"}";
    in pkgs.runCommand "src" {
      outputHashAlgo = "sha256";
      outputHashMode = "recursive";
      outputHash = sha256;
    } '''
      set -euo pipefail
      mkdir -p "\$out"
      tar -xf \''${./src.tar} -C "\$out"
    '''
    EOF
  '');

in rec {
  fromPath = path: pkgs.runCommand "from-path.ui" {} ''
    set -euo pipefail
    mkdir -p $out
    echo ${path} > $out/base
    cd ${path}
    find . > $out/paths
  '';

  toPath = ui: builtins.toPath "${import "${toUninvalidatedNix (toInvalidated ui)}"}";

  uninvalidate = path: toPath (fromPath path);
  
  bashPathFilter = name: filter: ui: pkgs.runCommand name {} ''
    set -euo pipefail
    mkdir -p "$out"
    local base=$(cat "${ui}/base")
    cp "${ui}/base" "$out/base"
    touch "$out/paths"
    while read path
    do
      local source="$base/$path"
      if (bash ${pkgs.writeText "${name}.sh" filter} "$source")
      then
        ${debugBash} && echo "+ $(realpath $source)" || true
        echo "$path" >> "$out/paths"
      else
        ${debugBash} && echo "- $(realpath $source)" || true
      fi
    done < "${ui}/paths"
  '';
  
  filterOutDirectories = bashPathFilter "filter-dirs" ''[[ ! -d "$1" ]]'';
}
