{
  config,
  pkgs,
  lib,
  ...
}:

let
  dockerRoot = ''"C:\Program Files\Docker\Docker\resources"'';
in
{
  system.stateVersion = "25.05";

  wsl = {
    enable = true;
    defaultUser = "nixos";
    useWindowsDriver = true;
    docker-desktop.enable = true;
  };

  systemd.services.docker-desktop-proxy = {
    path = [ pkgs.mount ];
    script = "${config.wsl.wslConf.automount.root}/wsl/docker-desktop/docker-desktop-user-distro proxy --docker-desktop-root ${config.wsl.wslConf.automount.root}/wsl/docker-desktop ${dockerRoot}";
  };

  # Enable the Flakes feature and the accompanying new nix command-line tool
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
  nixpkgs.config.allowUnfree = true;
  nixpkgs.config.allowUnfreePredicate = (_: true);

  environment = {
    systemPackages = with pkgs; [ git ];
    shells = with pkgs; [ zsh ];
  };
  programs.zsh.enable = true;
  users.defaultUserShell = pkgs.zsh;
}
