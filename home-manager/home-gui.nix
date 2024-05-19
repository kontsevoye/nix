{ config, pkgs, ... }:

{
  home.packages = with pkgs; [
    chromium
    keepassxc
    vlc
    streamlink-twitch-gui-bin
  ];
}

