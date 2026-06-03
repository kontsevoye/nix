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
        extraEntries."windows_11.conf" = ''
          title Windows 11
          efi /EFI/Microsoft/Boot/bootmgfw.efi
          sort-key o_windows
        '';
        extraInstallCommands = ''
          windows_esp="/run/windows-esp"
          ${pkgs.coreutils}/bin/mkdir -p "$windows_esp" "${config.boot.loader.efi.efiSysMountPoint}/EFI"
          if ! ${pkgs.util-linux}/bin/findmnt "$windows_esp" > /dev/null; then
            ${pkgs.util-linux}/bin/mount -o ro /dev/disk/by-uuid/24E3-376D "$windows_esp"
          fi
          if [ -d "$windows_esp/EFI/Microsoft" ]; then
            ${pkgs.coreutils}/bin/cp -R "$windows_esp/EFI/Microsoft" "${config.boot.loader.efi.efiSysMountPoint}/EFI/"
          fi

          loader_conf="${config.boot.loader.efi.efiSysMountPoint}/loader/loader.conf"
          if ${pkgs.gnugrep}/bin/grep -q '^auto-entries ' "$loader_conf"; then
            ${pkgs.gnused}/bin/sed -i 's/^auto-entries .*/auto-entries yes/' "$loader_conf"
          else
            printf 'auto-entries yes\n' >> "$loader_conf"
          fi

          if ${pkgs.gnugrep}/bin/grep -q '^default ' "$loader_conf"; then
            ${pkgs.gnused}/bin/sed -i 's/^default .*/default windows_11.conf/' "$loader_conf"
          else
            printf 'default windows_11.conf\n' >> "$loader_conf"
          fi
        '';
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

  programs = {
    zsh.enable = true;
    kdeconnect.enable = true;
    steam.enable = true;

    chromium = {
      enable = true;
      enablePlasmaBrowserIntegration = true;
    };
  };

  security = {
    rtkit.enable = true;
    pki.certificateFiles = [ ./homelab-root-ca.crt ];
  };

  services = {
    xserver = {
      enable = true;
      videoDrivers = [ "nvidia" ];
      xkb = {
        layout = "us,ru";
        options = "grp:caps_toggle";
      };
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
      gnome-disk-utility
      gptfdisk
      libva-utils
      mesa-demos
      ntfs3g
      pavucontrol
      pciutils
      parted
      kdePackages.partitionmanager
      kdePackages.xdg-desktop-portal-kde
      sops
      (writeShellApplication {
        name = "boot-windows";
        runtimeInputs = [
          systemd
        ];
        text = ''
          bootctl set-oneshot windows_11.conf
          systemctl reboot
        '';
      })
      (writeShellApplication {
        name = "boot-loader-menu";
        runtimeInputs = [
          systemd
        ];
        text = ''
          systemctl reboot --boot-loader-menu=10
        '';
      })
      usbutils
      vim
      vulkan-tools
      wget
      xdg-desktop-portal
      yandex-music
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
