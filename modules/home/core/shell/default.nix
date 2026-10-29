{ pkgs, config, ... }:
{

  home.packages = with pkgs; [

    #czkawka

  ];

  home.sessionVariables = {
    # Config files path
    DOTFILES = config.my.dotfiles.path;
  };

  # Aliases
  home.shellAliases = {

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
    dots =
      if config.programs.neovim.enable then
        ''cd $DOTFILES && nvim "+lua Snacks.picker.files()"''
      else
        ''code "$DOTFILES"'';

    # Update flake
    up = "dj update";

  };

}
