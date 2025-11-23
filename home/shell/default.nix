{ pkgs, ... }:
{

  imports = [

    # Shell
    ./shell/zsh.nix

    # Prompt
    ./prompt/starship.nix

    # Tools
    ./tools/default.nix

    # Multiplexer
    ./multiplexer/tmux.nix
    ./multiplexer/zellij.nix

    # Scripts
    ./scripts/default.nix

    # AI Assistants
    ./assistant/gemini.nix
    ./assistant/copilot.nix

    # Extra
    ./extra/fastfetch/default.nix
    ./extra/tldr.nix
    ./extra/aria2.nix

  ];

  home.packages = with pkgs; [

    unzip

    czkawka

  ];

  home.sessionVariables = {
    # Config files path
    DOTFILES = "$HOME/dotfiles";
  };

  # Aliases
  home.shellAliases = {

    # Clear
    c = "clear";

    # Create parent directories as needed
    mkdir = "mkdir -pv";

    # Confirm before overwriting or deleting
    cp = "cp -iv";
    mv = "mv -iv";
    rm = "rm -iv";

    # rsync
    rs = "rsync -Pazvhm";
    rsmv = "rsync -Pazvhm --remove-source-files";
    rsrepo = "rsync -Pazvhm --include='**.gitignore' --filter=':- .gitignore' --delete-after";

    # Edit configs
    dots = ''cd $DOTFILES && nvim "+lua Snacks.picker.files()"'';

    # Update flake
    up = "pushd $DOTFILES && just update && popd";

  };

}
