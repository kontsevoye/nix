{
  pkgs,
  lib,
  inputs,
  ...
}:

let
  username = "e.kontsevoy";
in
{
  imports = [ ../shared/nix-settings.nix ];

  nix.enable = true;
  # Use the open-source engine; nix-darwin still manages the daemon and GC.
  nix.package = inputs.determinate-nix.packages.${pkgs.stdenv.hostPlatform.system}.default;
  nix.settings = {
    lazy-trees = true;
    eval-cores = 0;
    extra-substituters = lib.mkAfter [ "https://install.determinate.systems" ];
  };
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
    # taps = [ "asheshgoplani/tap" ];
    brews = [
      # {
      #   name = "asheshgoplani/tap/agent-deck";
      #   trusted = true;
      # }
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
  home-manager.backupFileExtension = "before-home-manager";
  home-manager.users."${username}" = {
    imports = [
      ../home-manager/default.nix
      ../home-manager/machines/e.kontsevoy_at_e-kontsevoy-mac.nix
    ];
  };
  system.primaryUser = "${username}";
}
