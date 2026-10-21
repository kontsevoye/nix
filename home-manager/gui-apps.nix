{ pkgs, ... }:

{
  home.packages = with pkgs; [
    chromium
    keepassxc
    vlc
  ];
}
