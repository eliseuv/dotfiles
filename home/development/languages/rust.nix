{ pkgs, inputs, ... }:

{

  home.packages = with pkgs; [

    # Full stable rust toolchain via fenix
    inputs.fenix.packages.${pkgs.stdenv.hostPlatform.system}.stable.completeToolchain

    # Cargo
    cargo-watch
    cargo-generate
    cargo-cache
    cargo-binstall
    cargo-update
    cargo-cross
    cargo-fuzz
    cargo-nextest

    # CLI Crate Docs
    rusty-man

    # Compilation cache
    sccache

    # Debugging
    lldb

    # https://nixos.wiki/wiki/Rust#Building_Rust_crates_that_require_external_system_libraries
    openssl.dev
    pkg-config

  ];

  # Cargo will look for OpenSSL with pkg-config
  home.sessionVariables.PKG_CONFIG_PATH = "${pkgs.openssl.dev}/lib/pkgconfig";

  # Environment variables for Rust
  home.sessionVariables = {
    RUSTC_WRAPPER = "sccache";
    RUST_BACKTRACE = 1;
    RUST_LOG = "info";
  };

  # Background program analyzer
  programs.bacon = {
    enable = true;
    settings = {
      default_job = "clippy-all";
    };
  };

}
