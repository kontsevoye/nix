{
  config,
  lib,
  pkgs,
  ...
}:

{
  imports = [
    ../../shared/nix-settings.nix
    ./hardware-configuration.nix
    ./flatpaks.nix
    ./secrets.nix
  ];

  system.stateVersion = "26.05";

  networking = {
    hostName = "evkon-pc";
    domain = "lan";
    networkmanager.enable = true;
    firewall.enable = true;
  };

  nix.gc.dates = "weekly";

  time.timeZone = "Europe/Istanbul";
  i18n.defaultLocale = "en_US.UTF-8";
  console = {
    keyMap = "us";
    font = "${pkgs.kbd}/share/consolefonts/eurlatgr.psfu.gz";
    earlySetup = true;
  };

  boot = {
    loader = {
      timeout = 5;
      efi = {
        canTouchEfiVariables = true;
        efiSysMountPoint = "/boot";
      };
      systemd-boot = {
        enable = true;
        configurationLimit = 10;
        editor = false;
      };
    };
    kernelParams = [
      "nvidia-drm.modeset=1"
      "nvidia-drm.fbdev=1"
    ];
    extraModprobeConfig = ''
      options nvidia-drm modeset=1 fbdev=1
    '';
  };

  users = {
    mutableUsers = true;
    defaultUserShell = pkgs.zsh;
    users.evkon = {
      isNormalUser = true;
      description = "evkon";
      shell = pkgs.zsh;
      extraGroups = [
        "audio"
        "networkmanager"
        "video"
        "wheel"
      ];
    };
  };

  programs.zsh.enable = true;
  programs.kdeconnect.enable = true;
  programs.steam.enable = true;

  security = {
    rtkit.enable = true;
    pki.certificateFiles = [ ./homelab-root-ca.crt ];
  };

  services = {
    xserver = {
      enable = true;
      videoDrivers = [ "nvidia" ];
      xkb.layout = "us";
    };

    displayManager.sddm = {
      enable = true;
      wayland.enable = true;
    };
    desktopManager.plasma6.enable = true;

    pulseaudio.enable = false;
    pipewire = {
      enable = true;
      alsa = {
        enable = true;
        support32Bit = true;
      };
      pulse.enable = true;
      jack.enable = true;
      wireplumber.enable = true;
    };

    printing.enable = true;
    blueman.enable = true;
    fwupd.enable = true;
    fstrim.enable = true;
    power-profiles-daemon.enable = true;
    udisks2.enable = true;
  };

  hardware = {
    enableRedistributableFirmware = true;
    steam-hardware.enable = true;

    bluetooth = {
      enable = true;
      powerOnBoot = true;
    };

    graphics = {
      enable = true;
      enable32Bit = true;
      extraPackages = with pkgs; [ nvidia-vaapi-driver ];
    };

    nvidia = {
      modesetting.enable = true;
      open = true;
      nvidiaSettings = true;
      package = config.boot.kernelPackages.nvidiaPackages.latest;
      powerManagement.enable = true;
    };
  };

  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.kdePackages.xdg-desktop-portal-kde ];
  };

  environment = {
    sessionVariables = {
      NIXOS_OZONE_WL = "1";
      MOZ_ENABLE_WAYLAND = "1";
      LIBVA_DRIVER_NAME = "nvidia";
      NVD_BACKEND = "direct";
      __GLX_VENDOR_LIBRARY_NAME = "nvidia";
    };

    systemPackages = with pkgs; [
      age
      alsa-utils
      btrfs-progs
      bubblewrap
      crosspipe
      curl
      git
      libva-utils
      mesa-demos
      ntfs3g
      pavucontrol
      pciutils
      sops
      usbutils
      vim
      vulkan-tools
      wget
    ];
  };

  fonts.packages = with pkgs; [ nerd-fonts.hack ];

  virtualisation.podman = {
    enable = true;
    dockerCompat = true;
    defaultNetwork.settings.dns_enabled = true;
  };

  specialisation.safe-boot.configuration = {
    systemd.defaultUnit = "multi-user.target";

    boot.kernelParams = lib.mkForce [ "nomodeset" ];

    services = {
      flatpak.enable = lib.mkForce false;
      xserver.enable = lib.mkForce false;
      displayManager.sddm.enable = lib.mkForce false;
      desktopManager.plasma6.enable = lib.mkForce false;
    };

    xdg.portal.enable = lib.mkForce false;
  };
}
