{ lib, pkgs, ... }:

let
  homeDirectory = "/Users/e.kontsevoy";
  npmGlobalPrefix = "${homeDirectory}/.local/share/npm-global";
  orbStackBin = "${homeDirectory}/.orbstack/bin";
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
in
{
  home = {
    username = "e.kontsevoy";
    homeDirectory = homeDirectory;
    sessionPath = [
      "${npmGlobalPrefix}/bin"
      orbStackBin
    ];
    sessionVariables = {
      NPM_CONFIG_PREFIX = npmGlobalPrefix;
    };
    packages = [
      claudeCodeRouterUpdate
      codexAuto
      openClaudeUpdate
    ];
  };

  home.file.".codex/auto.config.toml".text = ''
    # Let Codex review eligible approval requests while keeping commands sandboxed.
    approval_policy = "on-request"
    approvals_reviewer = "auto_review"
    sandbox_mode = "workspace-write"
  '';

  programs.zsh.envExtra = lib.mkAfter ''
    path=("${npmGlobalPrefix}/bin" $path)
    path=("${orbStackBin}" $path)
  '';
}
