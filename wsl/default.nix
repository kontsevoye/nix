{ config, pkgs, ... }:

{
  system.stateVersion = "24.05";
  wsl.enable = true;
  wsl.defaultUser = "nixos";
  wsl.useWindowsDriver = true;

  programs.zsh.enable = true;
  users.defaultUserShell = pkgs.zsh;
  environment.shells = with pkgs; [ zsh ];

  # Enable the Flakes feature and the accompanying new nix command-line tool
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
  environment.systemPackages = with pkgs; [ git ];
}
