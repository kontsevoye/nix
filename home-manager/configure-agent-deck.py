"""Apply the Mac's managed Agent Deck settings, retaining other settings."""

from datetime import datetime
import os
from pathlib import Path
import shutil
import sys
import tempfile

import tomlkit


def main():
    path = Path(sys.argv[1]).expanduser()
    before = path.read_text() if path.exists() else ""
    config = tomlkit.parse(before)
    managed = {
        "tmux": {"socket_name": "agent-deck"},
        "ui": {"embedded_terminal": True},
        "updates": {
            "check_enabled": True,
            "auto_install": False,
            "auto_restart": False,
            "auto_update_remotes": False,
        },
    }
    for name, values in managed.items():
        if name not in config:
            config[name] = tomlkit.table()
        config[name].update(values)
    # Codex does not request modifyOtherKeys in tmux. Force modified keys to
    # reach it as CSI-u, while retaining the user's other tmux overrides.
    if "options" not in config["tmux"]:
        config["tmux"]["options"] = tomlkit.table()
    config["tmux"]["options"].update({
        "extended-keys": "always",
        "extended-keys-format": "csi-u",
    })
    after = tomlkit.dumps(config)
    tomlkit.parse(after)
    if after == before:
        print("Agent Deck settings already applied.")
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists():
        backup = path.with_name(path.name + ".before-my-nix-" + datetime.now().strftime("%Y%m%d-%H%M%S-%f"))
        shutil.copy2(path, backup)
        print(f"Backup: {backup}")
    fd, temporary = tempfile.mkstemp(prefix=".config-", dir=path.parent)
    try:
        with os.fdopen(fd, "w") as stream:
            stream.write(after)
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)
    print(f"Applied Agent Deck settings: {path}")


if __name__ == "__main__":
    main()
