home-switch:
    nh home switch .

system-test:
    nh os test .

system-switch:
    git diff -U0 '*.nix'
    nh os switch .
    git commit --all --allow-empty \
        --message "$(hostname) @ $(nixos-rebuild list-generations | rg "True$" | sd '^(\d+)\W+\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\W+([\w\.]+)\W+([\w\.]+).+True$' '$1 NixOS $2 Linux $3')" \
        --message "$(ls -dv1 /nix/var/nix/profiles/system-*-link | tail -2 | xargs -r nvd diff)"
    git push

system-boot:
    git diff -U0 '*.nix'
    nh os boot .
    git commit --all --allow-empty \
        --message "$(hostname) @ $(nixos-rebuild list-generations | rg "True$" | sd '^(\d+)\W+\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\W+([\w\.]+)\W+([\w\.]+).+True$' '$1 NixOS $2 Linux $3')" \
        --message "$(ls -dv1 /nix/var/nix/profiles/system-*-link | tail -2 | xargs -r nvd diff)"
    git push

update *inputs:
    nix flake update {{inputs}} --verbose
    git restore --staged .
    git add flake.lock
    git commit --message "[flake] update {{inputs}}"

update-os: update system-switch home-switch

update-home: (update "home-manager" "sops-nix" "spicetify-nix" "yt-x" "neovim-nightly-overlay") home-switch

update-neovim: (update "neovim-nightly-overlay") home-switch
    nvim --headless "+Lazy! sync" +qa

gc keep='8':
    nh clean all --keep {{keep}}
