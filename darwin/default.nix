{
  pkgs,
  lib,
  inputs,
  ...
}:

let
  username = "e.kontsevoy";
  # Official Amphetamine helper for closed-display sessions on Apple Silicon.
  powerProtectScript = pkgs.fetchurl {
    name = "amphetamine-power-protect.scpt";
    url = "https://raw.githubusercontent.com/x74353/Amphetamine/84740c43c66ee9fae9e6f668a7c129e84e9fd352/Files/powerProtect.scpt";
    hash = "sha256-p75QY4M6h2KaJT41lULdm1zEIJF9ljSxS1Zr3lS4qDQ=";
  };
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

  # Manage App Store apps separately from Homebrew's bundle cleanup.
  programs.mas = {
    enable = true;
    packages.Amphetamine = 937984704;
    cleanup = false;
    update = false;
  };

  # Preserve the two exact commands allowed by the official Power Protect installer.
  # The helper checks for this filename before invoking sudo without a password.
  environment.etc."sudoers.d/amphetamine_PowerProtect" = {
    text = ''
      Cmnd_Alias PMSET_AMPHETAMINE= /usr/bin/pmset -a disablesleep 1, /usr/bin/pmset -a disablesleep 0
      %admin ALL=(ALL) NOPASSWD: PMSET_AMPHETAMINE
    '';
    # Allow migration of the unmodified file installed by Power Protect.
    knownSha256Hashes = [ "ec97dfc137afb5278e01a069f96bf8ecc3862250f07fc0d00b0d9a330a3c5e93" ];
  };

  system.activationScripts.postActivation.text = lib.mkAfter ''
    echo >&2 "setting up Amphetamine Power Protect..."
    power_protect_dir=${lib.escapeShellArg "/Users/${username}/Library/Application Scripts/com.if.Amphetamine"}
    power_protect_file="$power_protect_dir/powerProtect.scpt"

    # Place a real file in the sandboxed app's Application Scripts directory.
    /usr/bin/install -d -o ${lib.escapeShellArg username} -g staff -m 700 "$power_protect_dir"
    if ! /usr/bin/cmp -s ${powerProtectScript} "$power_protect_file"; then
      if [ -e "$power_protect_file" ] && [ ! -e "$power_protect_file.before-nix-darwin" ]; then
        /bin/cp -p "$power_protect_file" "$power_protect_file.before-nix-darwin"
      fi
      /usr/bin/install -o root -g wheel -m 644 ${powerProtectScript} "$power_protect_file"
    fi
  '';

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
