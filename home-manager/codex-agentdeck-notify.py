"""Compose per-session Codex notifications without changing global notify."""

import argparse
from concurrent.futures import ThreadPoolExecutor
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tomllib


def config_override():
    instance = os.environ["AGENTDECK_INSTANCE_ID"]
    profile = os.environ.get("AGENTDECK_PROFILE", "default")
    codex_home = Path(os.environ.get("CODEX_HOME", Path.home() / ".codex"))
    original = []
    # codex-auto selects the auto profile. Preserve its notification override
    # if present, otherwise keep the root notification (Computer Use here).
    for path in (codex_home / "config.toml", codex_home / "auto.config.toml"):
        if path.exists():
            config = tomllib.loads(path.read_text())
            original = config.get("notify", original)
            if path.name == "config.toml":
                original = config.get("profiles", {}).get("auto", {}).get("notify", original)
    if not isinstance(original, list) or not all(isinstance(x, str) for x in original):
        raise ValueError("Codex notify must be an array of strings")
    agent_deck = shutil.which("agent-deck")
    if not agent_deck:
        raise ValueError("agent-deck is not on PATH")
    command = [
        sys.executable, str(Path(__file__).resolve()), "dispatch",
        "--instance", instance, "--profile", profile,
        "--codex-home", str(codex_home.resolve()),
        "--agent-deck", agent_deck,
        "--original", json.dumps(original, ensure_ascii=False), "--",
    ]
    # A JSON array of strings is also a TOML array. No shell evaluation.
    print("notify=" + json.dumps(command, ensure_ascii=False))


def callback(label, command, payload, stdin, env):
    try:
        result = subprocess.run(
            command + payload, input=stdin, env=env,
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=5,
        )
        if result.returncode:
            print(f"codex notify: {label} exited {result.returncode}", file=sys.stderr)
    except (OSError, subprocess.TimeoutExpired) as error:
        # Do not log the command, payload, or credentials from either callback.
        print(f"codex notify: {label}: {type(error).__name__}", file=sys.stderr)


def dispatch(args):
    payload = args.payload[1:] if args.payload[:1] == ["--"] else args.payload
    stdin = sys.stdin.buffer.read() if not payload and not sys.stdin.isatty() else b""
    original = json.loads(args.original)
    env = os.environ.copy()
    # The shared app-server's environment belongs to the daemon, not this
    # frontend. Use the identity captured by codex-auto at session launch.
    deck_env = env | {
        "AGENTDECK_INSTANCE_ID": args.instance,
        "AGENTDECK_PROFILE": args.profile,
        "CODEX_HOME": args.codex_home,
    }
    with ThreadPoolExecutor(max_workers=2) as pool:
        jobs = [pool.submit(callback, "Agent Deck", [args.agent_deck, "codex-notify"], payload, stdin, deck_env)]
        if original:
            jobs.append(pool.submit(callback, "original", original, payload, stdin, env))
        for job in jobs:
            job.result()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    commands.add_parser("config")
    run = commands.add_parser("dispatch")
    for name in ("instance", "profile", "codex-home", "agent-deck", "original"):
        run.add_argument("--" + name, required=True)
    run.add_argument("payload", nargs=argparse.REMAINDER)
    args = parser.parse_args()
    if args.command == "config":
        config_override()
    else:
        dispatch(args)


if __name__ == "__main__":
    main()
