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
      keybind = [
        "ctrl+shift+comma=reload_config"
        "ctrl+comma=open_config"
        "ctrl+shift+key_c=copy_to_clipboard:mixed"
        "ctrl+shift+key_v=paste_from_clipboard"
        "ctrl+equal=increase_font_size:1"
        "ctrl+shift+equal=increase_font_size:1"
        "ctrl+minus=decrease_font_size:1"
        "ctrl+digit_0=reset_font_size"
        "super+ctrl+shift+key_j=write_screen_file:copy,plain"
        "ctrl+shift+key_j=write_screen_file:paste,plain"
        "ctrl+alt+shift+key_j=write_screen_file:open,plain"
        "ctrl+shift+key_n=new_window"
        "ctrl+shift+key_w=close_tab:this"
        "ctrl+shift+key_q=quit"
        "ctrl+shift+key_t=new_tab"
        "ctrl+shift+key_o=new_split:right"
        "ctrl+shift+key_e=new_split:down"
        "super+ctrl+bracket_left=goto_split:previous"
        "super+ctrl+bracket_right=goto_split:next"
        "ctrl+shift+key_f=start_search"
        "ctrl+shift+key_i=inspector:toggle"
        "ctrl+shift+key_a=select_all"
        "ctrl+shift+key_p=toggle_command_palette"
        "global:ctrl+backquote=toggle_quick_terminal"
      ];
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
