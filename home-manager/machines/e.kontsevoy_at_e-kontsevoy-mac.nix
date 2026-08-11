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
      pkgs.ghostty-pr-9857
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

  programs.zsh.envExtra = lib.mkAfter ''
    path=("${npmGlobalPrefix}/bin" $path)
    path=("${orbStackBin}" $path)
    path=("${codexStandaloneBin}" $path)
  '';
}
