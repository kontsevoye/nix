{
  config,
  pkgs,
  ...
}:

let
  dockerRoot = ''"C:\Program Files\Docker\Docker\resources"'';
in
{
  imports = [ ../shared/nix-settings.nix ];

  system.stateVersion = "25.05";
  nixpkgs.hostPlatform = "x86_64-linux";

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

  nix.gc.dates = "weekly";

  environment = {
    systemPackages = with pkgs; [ git ];
    shells = with pkgs; [ zsh ];
  };
  programs.zsh.enable = true;
  users.defaultUserShell = pkgs.zsh;
}
