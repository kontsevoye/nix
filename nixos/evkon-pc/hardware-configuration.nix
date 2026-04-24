{
  config,
  lib,
  modulesPath,
  ...
}:

{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  boot.initrd.availableKernelModules = [
    "xhci_pci"
    "ahci"
    "nvme"
    "usb_storage"
    "sd_mod"
  ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];
  boot.blacklistedKernelModules = [
    "nouveau"
    "nova_core"
  ];

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/faaed0a5-1cbf-4218-8114-21a985dab993";
    fsType = "btrfs";
    options = [
      "subvol=root"
      "compress=zstd:1"
      "ssd"
      "discard=async"
    ];
  };

  fileSystems."/home" = {
    device = "/dev/disk/by-uuid/faaed0a5-1cbf-4218-8114-21a985dab993";
    fsType = "btrfs";
    options = [
      "subvol=home"
      "compress=zstd:1"
      "ssd"
      "discard=async"
    ];
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/801B-B94D";
    fsType = "vfat";
    options = [
      "umask=0077"
      "shortname=winnt"
    ];
  };

  swapDevices = [ ];

  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 25;
  };

  networking.useDHCP = lib.mkDefault true;
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
