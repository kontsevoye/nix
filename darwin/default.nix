{ pkgs, ... }:

{
  services.nix-daemon.enable = true;

  # Necessary for using flakes on this system.
  nix.settings.experimental-features = "nix-command flakes";
  nix.settings.extra-substituters = "https://devenv.cachix.org";
  nix.settings.extra-trusted-public-keys = "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw=";

  nix.settings.trusted-users = [
    "root"
    "e.kontsevoy"
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

  system.stateVersion = 4;
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
      "llamachat"
      "raycast"
      "jetbrains-toolbox"
      "orbstack"
      "diffusionbee"
      "deepl"
      "discord"
      "imazing"
      "keepassxc"
      "keka"
      "iterm2"
      "lunar"
      "microsoft-edge"
      "qbittorrent"
      "scroll-reverser"
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
      "telegram"
      "zoom"
    ];
    masApps = {
      "WireGuard" = 1451685025;
    };
  };

  users.users."e.kontsevoy" = {
    name = "e.kontsevoy";
    home = "/Users/e.kontsevoy";
  };
}
