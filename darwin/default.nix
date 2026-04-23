{ pkgs, lib, ... }:

let
  username = "e.kontsevoy";
in
{
  imports = [ ../shared/nix-settings.nix ];

  nix.enable = true;
  nix.settings.trusted-users = lib.mkAfter [ username ];
  nix.gc.interval = {
    Weekday = 0;
    Hour = 2;
    Minute = 0;
  };

  programs.zsh = {
    # enable nix & profile sourcing in /etc/{zshenv,zprofile,zshrc}
    # but disable defaults managed via home-manager
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
    brews = [
      "mas"
      "yubico-piv-tool"
    ];
    caskArgs = {
      appdir = "~/Applications";
      require_sha = true;
    };
    casks = [
      "hiddenbar"
      "raycast"
      "jetbrains-toolbox"
      "orbstack"
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
      "claude"
      "claude-code@latest"
      "codex"
      "copilot-cli"
      "rustdesk"
      "wallspace"
    ];
  };

  users.users."${username}" = {
    name = username;
    home = "/Users/${username}";
  };
  home-manager.users."${username}" = {
    imports = [
      ../home-manager/default.nix
      ../home-manager/machines/e.kontsevoy_at_e-kontsevoy-mac.nix
    ];
  };
  system.primaryUser = "${username}";
}
