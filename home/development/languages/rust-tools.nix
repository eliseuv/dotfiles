{ pkgs, lib, ... }:

let
  # Third-party Rust repos to keep cloned locally and cargo-install from source.
  # `path` is optional, for workspace repos where the installable binary crate
  # isn't at the workspace root.
  thirdPartyRustTools = [
    {
      url = "https://github.com/mpiorowski/late-sh.git";
      path = "late-cli";
    }
    { url = "https://github.com/Ataraxy-Labs/lazydiff.git"; }
    { url = "https://github.com/nol00p/Shoin.git"; }
    {
      url = "https://github.com/sudipghimire533/ytui-music.git";
      path = "front-end";
    }
  ];

  thirdPartyRustSrcDir = "$HOME/Projects/third-party/rust";

  # Encode each repo as "url|path" (path may be empty) for a flat bash array.
  toolEntries = lib.concatMapStringsSep " " (r: ''"${r.url}|${r.path or ""}"'') thirdPartyRustTools;

  rust-tools-install = pkgs.writeShellScriptBin "rust-tools-install" ''
    set -uo pipefail

    mkdir -p "${thirdPartyRustSrcDir}"

    entries=( ${toolEntries} )
    failed=()

    for entry in "''${entries[@]}"; do
      repo="''${entry%%|*}"
      subpath="''${entry#*|}"
      name=$(basename "$repo")
      name=''${name%.git}
      dest="${thirdPartyRustSrcDir}/$name"
      installPath="$dest"
      [ -n "$subpath" ] && installPath="$dest/$subpath"

      if (
        set -e
        if [ -d "$dest/.git" ]; then
          echo "Updating $name..."
          git -C "$dest" pull --ff-only
        else
          echo "Cloning $name..."
          git clone "$repo" "$dest"
        fi
        echo "Installing $name..."
        cargo install --path "$installPath" --force --locked
      ); then
        :
      else
        echo "FAILED: $name" >&2
        failed+=("$name")
      fi
    done

    if [ ''${#failed[@]} -gt 0 ]; then
      echo
      echo "Failed: ''${failed[*]}" >&2
      exit 1
    fi
  '';
in

{

  home.packages = [
    rust-tools-install
  ];

  home.shellAliases = {
    # Fetch and cargo-install the third-party Rust tools
    rti = "rust-tools-install";
  };

  # Kick off rust-tools-install as a detached unit on every switch, so
  # activation doesn't block on network/cargo-build time. A timestamped
  # unit name avoids clashing with a still-running previous invocation.
  # Check progress with `journalctl --user -u 'rust-tools-install-*'`.
  home.activation.rustToolsInstall = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run ${pkgs.systemd}/bin/systemd-run --user \
      --unit="rust-tools-install-$(date +%s)" \
      --description="Fetch and cargo-install third-party Rust tools" \
      --collect \
      -- ${lib.getExe rust-tools-install}
  '';

}
