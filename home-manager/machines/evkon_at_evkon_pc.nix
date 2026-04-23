{ ... }:

let
  ghosttyBin = "/usr/bin/ghostty";
in

{
  home = {
    username = "evkon";
    homeDirectory = "/home/evkon";
  };

  programs.ghostty = {
    enable = true;
    package = null;
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
