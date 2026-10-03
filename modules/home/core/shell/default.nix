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
