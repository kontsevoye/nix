{
  inputs,
  lib,
  osConfig ? null,
  pkgs,
  ...
}:

let
  chromePkgs = import inputs.nixpkgs-chrome {
    system = pkgs.stdenv.hostPlatform.system;
    config.allowUnfree = true;
  };
  telegramPkgs = import inputs.nixpkgs-telegram {
    system = pkgs.stdenv.hostPlatform.system;
    config.allowUnfree = true;
  };
  homeDirectory = "/home/evkon";
  npmGlobalPrefix = "${homeDirectory}/.local/share/npm-global";
  codexUpdate = pkgs.writeShellScriptBin "codex-update" ''
    set -euo pipefail

    export NPM_CONFIG_PREFIX=${lib.escapeShellArg npmGlobalPrefix}
    mkdir -p "$NPM_CONFIG_PREFIX"
    exec ${pkgs.nodejs_22}/bin/npm install --global @openai/codex@latest
  '';
  ghosttyPackage = if osConfig == null then null else pkgs.ghostty;
  ghosttyBin = if ghosttyPackage == null then "/usr/bin/ghostty" else lib.getExe ghosttyPackage;
in

{
  home = {
    username = "evkon";
    homeDirectory = homeDirectory;
    sessionPath = [ "${npmGlobalPrefix}/bin" ];
    sessionVariables = {
      NPM_CONFIG_PREFIX = npmGlobalPrefix;
    };
    packages =
      with pkgs;
      [
        bitwarden-desktop
        jetbrains-toolbox
        slack
        zoom-us
      ]
      ++ [
        chromePkgs.google-chrome
        codexUpdate
        telegramPkgs.telegram-desktop
      ];
  };

  programs.zsh.envExtra = lib.mkAfter ''
    path=("${npmGlobalPrefix}/bin" $path)
  '';

  programs.ghostty = {
    enable = true;
    package = ghosttyPackage;
    enableZshIntegration = true;
    systemd.enable = false;

    settings = {
      keybind = [ "global:ctrl+backquote=toggle_quick_terminal" ];
      quick-terminal-position = "top";
      quick-terminal-size = "40%";
      quick-terminal-autohide = false;
      gtk-quick-terminal-layer = "top";
    };
  };

  systemd.user.services."ghostty-quick-terminal" = {
    Unit = {
      Description = "Ghostty Quick Terminal";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };

    Service = {
      ExecStart = "${ghosttyBin} --initial-window=false --quit-after-last-window-closed=false";
    };

    Install.WantedBy = [ "graphical-session.target" ];
  };

}
