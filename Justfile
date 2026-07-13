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
    # --no-gcroots: nh's gcroots-directory scan doesn't cross-reference the
    # "keep N generations" logic, so it can mark the *current* home-manager
    # generation link and current-home as unprotected and prune their
    # indirect gcroots, letting the subsequent store gc collect
    # still-in-use paths. Generation pruning and the actual store gc are
    # unaffected by this flag; only the extra gcroots-directory sweep is
    # skipped. https://github.com/nix-community/nh/issues/201
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
