## Install

```bash
# From this checkout, after installing Nix:
sudo -H ./scripts/darwin-switch
```

## Update

### Update dependencies

```bash
# run inside current directory or change "." to the actual location
nix flake update .
```

### Rebuild configuration after changes

```bash
sudo -H ./scripts/darwin-switch
```

The same command handles both a fresh Mac and subsequent rebuilds. It builds
the final system before switching, using this checkout's locked inputs. Nix
must already be installed with a working daemon. The command targets the
`e-kontsevoy-mac` configuration, even if the fresh Mac has another hostname.

## Ghostty build prerequisites

The Ghostty PR #9857 package (Quick Terminal tabs) requires Xcode 27.1 in
`/Applications/Xcode.app` and its Metal component. After installing or updating
Xcode, install the component before rebuilding:

```bash
xcodebuild -downloadComponent MetalToolchain
```

The recipe checks the Xcode version and Metal toolchain identifier. It locates
the mounted compiler directly because `xcrun` component discovery does not
work for Nix build users with this Xcode release. The Swift compiler also gets
`-disable-sandbox` so its macro plugins can run inside Nix's build sandbox.

## Linux builds on macOS

The Mac imports [nix-rosetta-builder](https://github.com/cpick/nix-rosetta-builder)
through nix-darwin. The guest builds `aarch64-linux` natively and `x86_64-linux`
through Rosetta. It has 4 CPU cores, 4 GiB RAM, and a 64 GiB virtual disk.
The sparse disk grows as data is written; this is not a 64 GiB space reservation
or a limit on all host-side Nix store/cache usage.

Measured on 2026-10-19 after the smoke builds: the complete VM directory used
4.9 GiB. Its `diffdisk` had a logical size of 64 GiB but only 2.49 GiB allocated
on the host (5,217,888 blocks of 512 bytes).

`onDemand = true` keeps the VM stopped until Nix connects to it. After 5 minutes
of inactivity the guest powers off; its disk remains. Changing the upstream
module's generated VM configuration may recreate that disposable builder disk.

`scripts/darwin-switch` automates initial setup:

1. Install Rosetta if an x86_64 executable cannot run (accepting Apple's license).
2. Skip VM startup entirely if the final system is already in the local store.
   Otherwise check whether the permanent builder is registered with Nix and
   launchd, without connecting to SSH or waking its VM. Nix starts it if needed.
3. If a build is needed and the permanent builder is not registered, fetch the
   stock Linux builder guest from the Nix cache and start a temporary QEMU VM,
   accessible only on loopback.
   This does not activate an intermediate nix-darwin system.
4. Build the final system using that VM and activate the exact built output.
5. Shut down the temporary VM and remove its disk and temporary credentials,
   including on build/activation failure or interruption.

The temporary VM uses its own client key, pins the stock guest's host key,
and leaves `/etc/nix/builder_ed25519` and existing SSH configuration untouched.
Only its public client key is copied into the guest's Nix store. Port 31022
must be available if bootstrap is necessary; the permanent builder uses 31122.
The stock guest settings are unchanged to retain binary-cache availability;
if its cached Linux outputs are unavailable, another Linux builder is required.

For image generation, the module removes the `kvm` scheduling requirement from
the Rosetta disk-image derivation only. The pinned nixpkgs QEMU command supports
`kvm:tcg` fallback, allowing this image to build through software emulation in
the temporary guest on M1/M2 Macs without nested KVM. This can make initial image
generation slower; the temporary builder does not advertise KVM support.

The regular configuration registers the permanent VM with Nix automatically,
so subsequent Linux builds need no manual start/stop commands. Privileged SSH
diagnostics use `sudo ssh rosetta-builder`; ordinary Nix builds do not need sudo
for a user trusted by the Nix daemon.

To test bootstrap and build without installing Rosetta or activating the system:

```bash
./scripts/darwin-switch --build-only
```

This still temporarily starts a Linux VM when necessary. For system activation,
use the full command above. Direct
`darwin-rebuild switch --flake .` continues to work once a Linux builder is
available, but does not perform automatic bootstrap or install Rosetta.

Verified on the Mac on 2026-10-19: initial bootstrap and full system build,
cleanup after a build failure, a cached repeat without VM startup, and two
successful user-run activations. The permanent builder then started on its
first build request and built both `aarch64-linux` and `x86_64-linux` smoke
derivations. An active build lasting 330 seconds completed without being
interrupted by the 5 minute idle timeout. The VM subsequently powered off
without manual intervention; its Lima and Virtualization.framework processes
exited. A new uncached x86_64 Linux build then started it again and succeeded.

The pinned Lima foreground runner treats the guest's shutdown event as an
exit error, so launchd can report `last exit code = 1` after a normal idle
shutdown. This was observed together with successful builds and a successful
subsequent restart; that code alone does not establish a VM crash. See Lima's
[foreground event handling](https://github.com/cpick/lima/blob/afbfdfb8dd5fa370547b7fc64a16ce2a354b1ff0/pkg/instance/start.go#L295).

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
sudo -H ./scripts/darwin-switch
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

## Amphetamine and Power Protect

`darwin/default.nix` declares Amphetamine (App Store ID `937984704`) through
`programs.mas.packages`. MAS cleanup and automatic updates are disabled; the
existing Homebrew `zap` cleanup remains separate from App Store apps.

The same module installs [Power Protect](https://github.com/x74353/Amphetamine),
the helper used for closed-display sessions on Apple Silicon. Its official
`Files/powerProtect.scpt` is pinned to commit
`84740c43c66ee9fae9e6f668a7c129e84e9fd352` with a SHA-256 hash. Activation copies
it to `~/Library/Application Scripts/com.if.Amphetamine/powerProtect.scpt` as a
regular file. An existing, different script is preserved as
`powerProtect.scpt.before-nix-darwin` before the first replacement.

Nix also manages `/etc/sudoers.d/amphetamine_PowerProtect`, preserving the
official installer's permission for members of `admin` to run only these two
commands without a password:

```text
/usr/bin/pmset -a disablesleep 1
/usr/bin/pmset -a disablesleep 0
```

The recognized original sudoers file is backed up by nix-darwin during its
first migration; unexpected contents cause activation to stop for review.
Installing these files does not itself disable sleep. Amphetamine controls
the sleep restriction while a session is running.

Session settings remain in Amphetamine and are not overwritten by Nix. The
configured power-adapter trigger keeps the Mac awake with its lid closed on
AC power. A manually started session, such as **Indefinitely**, can do the
same on battery when **Allow system sleep when display is closed** is off.
Simply opening the app does not start a manual session. **Allow display sleep**
can stay on in both cases. A low-battery session cutoff can be set in
**Session Defaults**; it is currently disabled.

After activation, `pmset -g` should show `SleepDisabled 1` during a
closed-display session with Power Protect, and `SleepDisabled 0` after all
such sessions end. Actual closed-lid operation and remote SSH still require
a check from another device.

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

The `auto` profile is initialized as a writable `~/.codex/auto.config.toml`,
with `gpt-6.1-sol` and `model_reasoning_effort = "high"` as its defaults.
Home Manager does not overwrite it on later rebuilds, so model changes made in
the Codex TUI persist. To update an existing profile, change `model` and
`model_reasoning_effort` in that file.

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

Agent Deck is installed independently at `~/go/bin/agent-deck` and updated with
`agent-deck update` (installed version checked on 2026-10-19: 1.16.30). The former
local tmux health patch and its build script have been removed; Nix does not
build or replace the Agent Deck binary.

Home Manager provides `agent-deck-configure` and runs it at activation.
It updates only these settings in the mutable `~/.config/agent-deck/config.toml`:

```toml
[tmux]
socket_name = "agent-deck"

[tmux.options]
extended-keys = "always"
extended-keys-format = "csi-u"

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

`extended-keys = "always"` preserves Shift+Enter even when an application
does not request extended keyboard input. With Agent Deck 1.16.26 and Codex
0.160.0, Codex panes remain in `VT10x` mode while Claude requests `Ext 2`;
the default `on` therefore turns Shift+Enter into ordinary Enter for Codex.
The `csi-u` format preserves the modifier for both applications. To update the
running server without restarting sessions:

```sh
tmux -L agent-deck set-option -s extended-keys always
tmux -L agent-deck set-option -s extended-keys-format csi-u
```

Restart the Agent Deck dashboard after activation so it reloads these overrides
before creating more sessions. Existing agent processes can keep running.

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
