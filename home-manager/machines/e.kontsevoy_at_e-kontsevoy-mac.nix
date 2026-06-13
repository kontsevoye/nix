{ lib, pkgs, ... }:

let
  homeDirectory = "/Users/e.kontsevoy";
  npmGlobalPrefix = "${homeDirectory}/.local/share/npm-global";
  claudeCodeRouterUpdate = pkgs.writeShellScriptBin "claude-code-router-update" ''
    set -euo pipefail

    export NPM_CONFIG_PREFIX=${lib.escapeShellArg npmGlobalPrefix}
    mkdir -p "$NPM_CONFIG_PREFIX"
    exec ${pkgs.nodejs_22}/bin/npm install --global @musistudio/claude-code-router@latest
  '';
in
{
  home = {
    username = "e.kontsevoy";
    homeDirectory = homeDirectory;
    sessionPath = [ "${npmGlobalPrefix}/bin" ];
    sessionVariables = {
      NPM_CONFIG_PREFIX = npmGlobalPrefix;
    };
    packages = [ claudeCodeRouterUpdate ];
  };

  programs.zsh.envExtra = lib.mkAfter ''
    path=("${npmGlobalPrefix}/bin" $path)
  '';
}
