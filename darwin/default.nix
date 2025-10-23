{ pkgs, ... }:

let username = "e.kontsevoy";
in {
  nix.enable = true;

  # Necessary for using flakes on this system.
  #nix.settings.experimental-features = "nix-command flakes";
  nix.settings.experimental-features = [ "nix-command flakes" ];
  nix.settings.extra-substituters = [
    "https://devenv.cachix.org"
    "https://nix-community.cachix.org"
    "https://kontsevoye.cachix.org"
  ];
  nix.settings.extra-trusted-public-keys = [
    "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw="
    "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    "kontsevoye.cachix.org-1:ZuSYCN/a5dirtTesvyrwmLwXzohZ+CpQqSrwXrchcrc="
    "cache.flakehub.com-3:hJuILl5sVK4iKm86JzgdXW12Y2Hwd5G07qKtHTOcDCM="
    "cache.flakehub.com-4:Asi8qIv291s0aYLyH6IOnr5Kf6+OF14WVjkE6t3xMio="
    "cache.flakehub.com-5:zB96CRlL7tiPtzA9/WKyPkp3A2vqxqgdgyTVNGShPDU="
    "cache.flakehub.com-6:W4EGFwAGgBj3he7c5fNh9NkOXw0PUVaxygCVKeuvaqU="
    "cache.flakehub.com-7:mvxJ2DZVHn/kRxlIaxYNMuDG1OvMckZu32um1TadOR8="
    "cache.flakehub.com-8:moO+OVS0mnTjBTcOUh2kYLQEd59ExzyoW1QgQ8XAARQ="
    "cache.flakehub.com-9:wChaSeTI6TeCuV/Sg2513ZIM9i0qJaYsF+lZCXg0J6o="
    "cache.flakehub.com-10:2GqeNlIp6AKp4EF2MVbE1kBOp9iBSyo0UPR9KoR0o1Y="
  ];
  nix.settings.trusted-users = [
    username
  ];

  nixpkgs.config.allowUnfree = true;
  nixpkgs.config.allowUnfreePredicate = (_: true);

  programs.zsh = {
    # enable nix & profile sourcing in /etc/{zshenv,zprofile,zshrc}
    # but disable all enabled dy default configs as they would be managed in home-manager
    enable = true;
    # default true
    enableBashCompletion = false;
    # default true
    enableCompletion = false;
    # default "autoload -U promptinit && promptinit && prompt walters && setopt prompt_sp"
    promptInit = "";
  };

  system.stateVersion = 6;
  nixpkgs.hostPlatform = "aarch64-darwin";

  homebrew = {
    enable = true;
    onActivation.cleanup = "zap";
    global.brewfile = true;
    brews = [ "mas" ];
    caskArgs = {
      appdir = "~/Applications";
      require_sha = true;
    };
    casks = [
      "hiddenbar"
      "raycast"
      "jetbrains-toolbox"
      "orbstack"
      "deepl"
      "discord"
      "keepassxc"
      "keka"
      "iterm2"
      "lunar"
      "microsoft-edge"
      "qbittorrent"
      "unnaturalscrollwheels"
      "steam"
      "sublime-text"
      "visual-studio-code"
      "vlc"
      "whisky"
      "yandex-disk"
      "yandex-music"
      "slack"
      "pritunl"
      "openvpn-connect"
      "zoom"
      "localsend"
      "ghostty"
    ];
  };

  users.users."${username}" = {
    name = username;
    home = "/Users/${username}";
  };
  home-manager.users."${username}" = import ../home-manager/default.nix;
  system.primaryUser = "${username}";
}
