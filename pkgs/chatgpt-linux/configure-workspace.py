"""Keep the user's other settings while adding dotfiles to new chat permissions."""

import json
import os
from pathlib import Path
import shutil
import sys
import tempfile

import tomlkit


def save(path, text):
    if path.exists() and path.read_text() == text:
        return
    backup = path.with_name(path.name + ".before-dotfiles-default")
    if path.exists() and not backup.exists():
        shutil.copy2(path, backup)
    with tempfile.NamedTemporaryFile(mode="w", dir=path.parent, delete=False) as f:
        f.write(text)
        temporary = f.name
    os.replace(temporary, path)


workspace = sys.argv[1]
if not workspace:
    sys.exit(0)
codex_home = Path(os.environ.get("CODEX_HOME", Path.home() / ".codex"))
codex_home.mkdir(parents=True, exist_ok=True)
config_path = codex_home / "config.toml"
config = tomlkit.parse(config_path.read_text()) if config_path.exists() else tomlkit.document()
profile_name = "dotfiles"
config["default_permissions"] = profile_name
permissions = config.setdefault("permissions", {})
profile = permissions.setdefault(profile_name, {})
profile["description"] = "Pasta da conversa e dotfiles da usuária"
profile["extends"] = ":workspace"
profile.setdefault("workspace_roots", {})[workspace] = True
save(config_path, tomlkit.dumps(config))

# A remembered choice in the desktop app takes precedence over config.toml.
# Apply this before launch so the app loads the same default as the CLI.
state_path = codex_home / ".codex-global-state.json"
state = json.loads(state_path.read_text()) if state_path.exists() else {}
atoms = state.setdefault("electron-persisted-atom-state", {})
atoms["permission-selection-by-host-id:local"] = {"kind": "profile", "profileId": profile_name}
save(state_path, json.dumps(state, ensure_ascii=False, separators=(",", ":")))
