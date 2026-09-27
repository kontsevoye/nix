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
sudo darwin-rebuild switch --flake .
```

## Nix engine

The Mac uses the open-source Determinate Nix engine from
`DeterminateSystems/nix-src`, pinned to release `v3.22.3` in `flake.nix` and to an
exact revision in `flake.lock`. nix-darwin still manages the standard Nix daemon,
configuration, build users, and garbage collection (`nix.enable = true`). This
does not install `determinate-nixd` or the Determinate installer/module.

`darwin/default.nix` enables lazy trees and evaluation across all CPU cores. It
also adds the public `https://install.determinate.systems` binary cache; its
signing keys are already declared in `shared/nix-settings.nix`. Linux hosts keep
their existing Nix package and settings.

To upgrade the engine, change its release tag in `flake.nix`, then run:

```bash
nix flake update determinate-nix
nix build .#darwinConfigurations.e-kontsevoy-mac.system --no-link
sudo darwin-rebuild switch --flake .
```

Keep the engine's own nixpkgs input: making it follow the system's nixpkgs can
change its dependency set and cause binary-cache misses.

### Roll back the engine trial

Before the 2026-09-14 trial, generation **36** used upstream Nix **2.34.8**.
To reactivate that generation without evaluating the modified flake:

```bash
sudo /nix/store/j4ri6vb80p9rjqfspc0w49klchlkncy6-darwin-system-26.11.4cff07d/sw/bin/darwin-rebuild --switch-generation 36
```

This rolls back the active system, not the repository. For a permanent return to
upstream Nix, remove the `determinate-nix` input, its `nix.package` assignment,
the `lazy-trees` and `eval-cores` settings, and the Determinate cache from the
Darwin module. Remove the now-unused `inputs` module argument and Darwin
`specialArgs`, run `nix flake lock`, then rebuild and switch normally.

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

The wrapper ensures the local app-server daemon is running and connects with
`codex --remote unix:// --profile auto`. In Codex CLI 0.157.1, `--profile` disables
automatic daemon selection; an explicit local socket connection keeps the
profile and shared server together. `--approve-for-me` alone also triggers the
embedded fallback in this version, so it is not a substitute for that connection.
The shared server lets sessions continue after the terminal disconnects and
makes them available through `codex agents`. Multi-agent tools are a separate
setting and are enabled by default; the embedded-mode warning does not itself
disable them.

The wrapper passes the current working directory explicitly because remote
connections otherwise inherit the server's directory. An explicit `-C` or `--cd`
takes precedence; other arguments are forwarded to Codex.

The `auto` profile is initialized as a writable `~/.codex/auto.config.toml`.
Home Manager does not overwrite it on later rebuilds, so model changes made in
the Codex TUI persist.

In principle, the built-in `--approve-for-me` flag can replace the profile's
permission settings: `approval_policy = "on-request"`,
`approvals_reviewer = "auto_review"`, and `sandbox_mode = "workspace-write"`.
The separate `auto` profile could therefore be removed if its model, reasoning,
and other profile-specific preferences are no longer needed or are moved to the
regular configuration. The flag is not marked experimental in CLI 0.157.1, and
`codex features list` reports `guardian_approval` as stable. This potential
simplification still requires the explicit `--remote unix://` connection in
0.157.1 because the flag alone also selects embedded mode.

Verified with CLI and daemon 0.157.1: `/status` shows the local Unix socket,
`Workspace (Approve for me)`, the selected profile's model/reasoning, and the
requested working directory. Exiting reports that running work continues and
offers the `agents` command. No model task or subagent was started for this check.

## Codex YOLO mode

The Mac Home Manager profile also installs a `codex-yolo` command. It starts
Codex without approval prompts or sandbox restrictions:

```bash
codex-yolo
```

This mode gives Codex unrestricted access to files, commands, and the network.
Use it only in an environment where that level of access is intentional.

The `yolo` profile is initialized as a writable `~/.codex/yolo.config.toml`, so
model changes made in the Codex TUI persist across Home Manager rebuilds.
