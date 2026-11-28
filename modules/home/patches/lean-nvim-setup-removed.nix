{
  config,
  lib,
  ...
}:
let
  id = "lean-nvim-setup-removed";
in
{

  # Metadata only: the fix is a lazy.nvim spec in the Neovim config's own
  # repository (~/.config/nvim/lua/plugins/lean.lua), which `locations` can't
  # name and no evaluation can inspect.
  config = lib.mkIf config.programs.neovim.enable {

    my.patches.${id} = {
      description = ''
        In the Neovim config repository (eliseuv/nvim, outside this one),
        lua/plugins/lean.lua publishes lean.nvim's opts as vim.g.lean_config in
        `init` and no-ops `config`. lean.nvim removed setup(), which lazy.nvim
        still calls for the opts of LazyVim's lang.lean extra, so loading it on
        a Lean file failed.
      '';
      upstream = [
        "https://github.com/LazyVim/LazyVim/pull/7276"
        "https://github.com/Julian/lean.nvim/commit/ca4393dcf762ac7f6ec6dc107f4ae2c7e4a395e2"
      ];
      removeWhen = ''
        The installed LazyVim
        (~/.local/share/nvim/lazy/LazyVim/lua/lazyvim/plugins/extras/lang/lean.lua)
        no longer leaves lazy.nvim to call setup(): it sets vim.g.lean_config
        itself, or the extra is gone. Then delete the comment, `init` and
        `config` from lua/plugins/lean.lua, keeping `opts` (if the extra is
        gone, the spec also needs its own load trigger and options), commit in
        that repository, and open a .lean file to confirm it loads without
        errors.
      '';
      added = "2026-11-27";
      status = {
        checked = "2026-11-27";
        note = ''
          LazyVim #7276, which makes the same change in the extra, is open; a
          contributor there suggests removing the extra instead. The installed
          LazyVim (0fa4a847) and the extra on LazyVim's default branch still
          rely on setup().
        '';
      };
    };

  };

}
