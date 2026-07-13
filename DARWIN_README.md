## Install

```bash
# run inside current directory or change "." to the actual location
nix --extra-experimental-features "nix-command flakes" run nix-darwin -- switch --flake .
```

## Update

### Update dependencies

```bash
# run inside current directory or change "." to the actual location
nix flake update .
```

### Rebuild configuration after changes

```bash
# run inside current directory or change "." to the actual location
darwin-rebuild switch --flake .
```

## NPM tools

`@musistudio/claude-code-router` is installed through npm instead of nixpkgs. The Mac Home Manager profile provides a `claude-code-router-update` command that installs or updates `@musistudio/claude-code-router@latest`.

```bash
claude-code-router-update
```

`@gitlawb/openclaude` is also installed through npm. The Mac Home Manager profile provides an `openclaude-update` command that installs or updates `@gitlawb/openclaude@latest`.

```bash
openclaude-update
```

## Codex auto mode

The Mac Home Manager profile installs a `codex-auto` command. It starts Codex
with the `auto` profile: commands remain restricted to the workspace sandbox,
while Codex's reviewer subagent handles eligible approval requests.

```bash
codex-auto
```

The regular `codex` command keeps its existing approval behavior.

The `auto` profile is initialized as a writable `~/.codex/auto.config.toml`.
Home Manager does not overwrite it on later rebuilds, so model changes made in
the Codex TUI persist.
