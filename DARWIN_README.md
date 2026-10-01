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

## Agent Deck integration

Agent Deck is installed independently at `~/go/bin/agent-deck` (audited version
1.16.22). Home Manager provides `agent-deck-configure` and runs it at activation.
It updates only these settings in the mutable `~/.config/agent-deck/config.toml`:

```toml
[tmux]
socket_name = "agent-deck"

[ui]
embedded_terminal = true

[updates]
check_enabled = true
auto_install = false
auto_restart = false
auto_update_remotes = false
```

Other settings and comments are preserved. Before changing a file, the helper
creates `config.toml.before-my-nix-<timestamp>` beside it; unchanged files are
not rewritten. These keys are managed by Nix, so subsequent activation restores
them if they were changed in the Settings UI. Update Agent Deck manually with
`agent-deck update`.

New Agent Deck sessions use the separate `tmux -L agent-deck` server. Existing
sessions retain their stored socket, including across `session restart`:
changing the default does not move live processes or saved session records.
Finish existing work on its current socket and create new sessions to use the
isolated server. There is no built-in socket migration command in 1.16.22.

The embedded layout keeps a session sidebar next to the interactive terminal:
Enter focuses the terminal, Alt+Enter opens a full-screen attach, and Ctrl+Q
returns to the dashboard. Restart the Agent Deck TUI after changing this setting.

### Codex notifications and the shared server

When launched by Agent Deck, `codex-auto` captures `AGENTDECK_INSTANCE_ID` and
`AGENTDECK_PROFILE` in a per-session `notify` override. The notification bridge
runs both the existing notification command (Computer Use on this Mac) and
`agent-deck codex-notify`. It forwards the original arguments without shell
evaluation, runs the callbacks independently with timeouts, and gives only the
Agent Deck callback the captured identity. This avoids attributing events to
whichever session originally started the shared daemon.

The global `~/.codex/config.toml` notification remains unchanged. The override
uses explicit `--remote unix://`, tested against CLI/server 0.159.3 with `/status`
confirming the shared server, auto permissions and requested directory. Outside
Agent Deck, `codex-auto` continues to use the original notification unchanged.
`agent-deck codex-hooks status` still reports `CUSTOM_NOTIFY`, because that
command inspects the global file rather than the per-session override. Do not
replace Computer Use's global notify with `codex-hooks install`.

### Apply and verify

From this checkout:

```bash
sudo darwin-rebuild switch --flake .
```

Then quit the Agent Deck dashboard with `q` and launch `agent-deck` again.
Existing agent tasks keep running when the dashboard exits. New Codex sessions
use the notification bridge; restart older Codex sessions with `R` only after
their current work is finished if they need the bridge too. The shared Codex
daemon does not need a restart for the per-session override.

After creating a new session:

```bash
tmux -L agent-deck ls
agent-deck doctor
```

No proxy hostname is configured on this Mac. If Web UI is later exposed through
a reverse proxy or Tailscale Serve, add its actual hostname to `[web].allowed_hosts`;
1.16.22 rejects unlisted hosts with HTTP 421. Recall remains opt-in and disabled.

Verified: both Nix packages and the complete Darwin system build; configuration
updates preserve unrelated settings and are idempotent; callback tests cover exact payload forwarding,
per-session identity overriding daemon identity, callback failure and timeout.
The notification bridge has not yet been observed on a real completed model turn.

References: [socket isolation](https://github.com/asheshgoplani/agent-deck/blob/v1.16.22/README.md#socket-isolation-v1750),
[configuration](https://github.com/asheshgoplani/agent-deck/blob/v1.16.22/skills/agent-deck/references/config-reference.md),
[1.16.22 changes](https://github.com/asheshgoplani/agent-deck/releases/tag/v1.16.22).

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
