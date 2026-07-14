update *inputs:
    nix flake update {{inputs}} --verbose
    git restore --staged .
    git add flake.lock
    git commit --message "[flake] update {{inputs}}"

commit-gen:
    git commit --all --allow-empty \
        --message "$(hostname) @ $(nixos-rebuild list-generations | rg "True$" | sd '^(\d+)\W+\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\W+([\w\.]+)\W+([\w\.]+).+True$' '$1 NixOS $2 Linux $3')" \
        --message "$(ls -dv1 /nix/var/nix/profiles/system-*-link | tail -2 | xargs -r nvd diff)"
    git push

gc keep='4':
    nh clean all --keep {{keep}} --no-gcroots

home-switch:
    nh home switch .

system-test: && home-switch
    nh os test .

system-switch: && commit-gen home-switch gc
    git diff -U0 '*.nix'
    nh os switch .

system-boot: && commit-gen home-switch gc
    git diff -U0 '*.nix'
    nh os boot .

update-system:
    -{{just_executable()}} update nixpkgs && {{just_executable()}} system-switch
    {{just_executable()}} update-home

update-home:
    -{{just_executable()}} update
    {{just_executable()}} home-switch
