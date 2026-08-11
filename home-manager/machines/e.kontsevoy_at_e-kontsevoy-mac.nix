{ lib, pkgs, ... }:

let
  homeDirectory = "/Users/e.kontsevoy";
  npmGlobalPrefix = "${homeDirectory}/.local/share/npm-global";
  orbStackBin = "${homeDirectory}/.orbstack/bin";
  codexStandaloneBin = "${homeDirectory}/.codex/packages/standalone/current/bin";
  claudeCodeRouterUpdate = pkgs.writeShellScriptBin "claude-code-router-update" ''
    set -euo pipefail

    export NPM_CONFIG_PREFIX=${lib.escapeShellArg npmGlobalPrefix}
    mkdir -p "$NPM_CONFIG_PREFIX"
    exec ${pkgs.nodejs_22}/bin/npm install --global @musistudio/claude-code-router@latest
  '';
  openClaudeUpdate = pkgs.writeShellScriptBin "openclaude-update" ''
    set -euo pipefail

    export NPM_CONFIG_PREFIX=${lib.escapeShellArg npmGlobalPrefix}
    mkdir -p "$NPM_CONFIG_PREFIX"
    exec ${pkgs.nodejs_22}/bin/npm install --global @gitlawb/openclaude@latest
  '';
  codexAuto = pkgs.writeShellScriptBin "codex-auto" ''
    exec codex --profile auto "$@"
  '';
  codexAutoConfig = pkgs.writeText "codex-auto.config.toml" ''
    # Let Codex review eligible approval requests while keeping commands sandboxed.
    approval_policy = "on-request"
    approvals_reviewer = "auto_review"
    sandbox_mode = "workspace-write"
  '';
  codexYolo = pkgs.writeShellScriptBin "codex-yolo" ''
    exec codex --profile yolo "$@"
  '';
  codexYoloConfig = pkgs.writeText "codex-yolo.config.toml" ''
    # Run without approval prompts or sandbox restrictions.
    approval_policy = "never"
    sandbox_mode = "danger-full-access"
  '';
in
{
  home = {
    username = "e.kontsevoy";
    homeDirectory = homeDirectory;
    sessionPath = [
      "${npmGlobalPrefix}/bin"
      orbStackBin
      codexStandaloneBin
    ];
    sessionVariables = {
      NPM_CONFIG_PREFIX = npmGlobalPrefix;
    };
    packages = [
      claudeCodeRouterUpdate
      codexAuto
      codexYolo
      openClaudeUpdate
    ];
  };

  home.activation.initializeCodexAutoConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    config_file=${lib.escapeShellArg "${homeDirectory}/.codex/auto.config.toml"}

    # Migrate the read-only file created by the previous home.file definition.
    if [ -L "$config_file" ] && [[ "$(readlink "$config_file")" == /nix/store/* ]]; then
      run rm "$config_file"
    fi

    # Keep the profile mutable so the Codex TUI can persist model selections.
    if [ ! -e "$config_file" ]; then
      run mkdir -p "$(dirname "$config_file")"
      run install -m 600 ${codexAutoConfig} "$config_file"
    fi
  '';

  home.activation.initializeCodexYoloConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    config_file=${lib.escapeShellArg "${homeDirectory}/.codex/yolo.config.toml"}

    # Keep the profile mutable so the Codex TUI can persist model selections.
    if [ ! -e "$config_file" ]; then
      run mkdir -p "$(dirname "$config_file")"
      run install -m 600 ${codexYoloConfig} "$config_file"
    fi
  '';

  programs.ghostty = {
    # Manage Ghostty with Home Manager.
    enable = true;
    # Use the pinned quick-terminal tabs revision.
    package = pkgs.ghostty-pr-9857;

    settings = {
      # Use the iTerm2 profile font.
      font-family = "Hack Nerd Font Mono";
      # Match the iTerm2 font size.
      font-size = 13;
      # Add vertical spacing between lines.
      adjust-cell-height = "10%";
      # Keep selections out of the clipboard.
      copy-on-select = false;
      # Preserve native macOS Option behavior.
      macos-option-as-alt = false;
      # Keep the cursor steady.
      cursor-style-blink = false;
      # Keep all terminal history.
      scrollback-limit-bytes = "unlimited";
      # Close terminals without confirmation.
      confirm-close-surface = false;
      # Toggle the terminal from any application.
      keybind = [ "global:ctrl+backquote=toggle_quick_terminal" ];
      # Drop down from the screen top.
      quick-terminal-position = "top";
      # Use forty percent of screen height.
      quick-terminal-size = "40%";
      # Follow the screen under the pointer.
      quick-terminal-screen = "mouse";
      # Show and hide without animation.
      quick-terminal-animation-duration = 0;
      # Hide when focus moves elsewhere.
      quick-terminal-autohide = true;
      # Follow the active macOS Space.
      quick-terminal-space-behavior = "move";
    };
  };

  programs.zsh.envExtra = lib.mkAfter ''
    path=("${npmGlobalPrefix}/bin" $path)
    path=("${orbStackBin}" $path)
    path=("${codexStandaloneBin}" $path)
  '';
}
