{ config, pkgs, ... }:

{
  home.packages = with pkgs; [
    zoom-us
    slack
    pritunl-client
    vlc-bin
    vscode
    unnaturalscrollwheels
    qbittorrent
    iterm2
    keka
    keepassxc
    discord
    raycast
    ollama
    hidden-bar
  ];
}
