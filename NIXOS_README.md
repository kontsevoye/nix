# NixOS

This repository exposes a full NixOS configuration for `evkon-pc`:

```bash
github:kontsevoye/nix/master#evkon-pc
```

The repository is public, so a fresh NixOS installer can reference it directly without cloning it first.
When installing from the GitHub URL, make sure the required changes are committed and pushed first.

## What It Configures

- Hostname: `evkon-pc.lan`
- User: `evkon`
- Desktop: KDE Plasma 6 with SDDM on Wayland
- GPU: NVIDIA RTX 4070 with the proprietary NVIDIA stack and open kernel module
- Audio: PipeWire with ALSA, PulseAudio compatibility, JACK, and WirePlumber
- Boot: UEFI + GRUB with OS prober enabled
- Filesystems: the current machine's Btrfs/ext4/vfat UUIDs
- Home Manager: the existing `evkon@evkon-pc` profile
- Trust store: the local homelab root CA
- Flatpak: the currently installed system Flatpak applications from Flathub

## Important Disk Layout Note

The current hardware configuration is machine-specific. It points to the existing Fedora disk layout:

```text
/         UUID=faaed0a5-1cbf-4218-8114-21a985dab993  btrfs subvol=root
/home     UUID=faaed0a5-1cbf-4218-8114-21a985dab993  btrfs subvol=home
/boot     UUID=94a02c88-01f7-4d05-9f22-459b0d6440d6  ext4
/boot/efi UUID=801B-B94D                             vfat
```

As written, `/` uses `subvol=root`, which is also the current Fedora root subvolume. If you want to keep Fedora available for rollback, create a separate Btrfs subvolume for NixOS and update `nixos/evkon-pc/hardware-configuration.nix` before installing.

For example, if you create a `nixos` subvolume, change the root filesystem option from:

```nix
"subvol=root"
```

to:

```nix
"subvol=nixos"
```

Commit and push that change before installing from the GitHub flake URL.

## Clean Existing Fedora Layout

`nixos-install` does not clean partitions or subvolumes. It installs into whatever is already mounted under `/mnt`.

If Fedora is no longer needed and you want to reuse the current partition layout, clean the old Btrfs subvolumes before mounting the target system for installation.

This deletes the existing Fedora `/` and `/home` contents:

```bash
sudo mount -o subvolid=5 /dev/disk/by-uuid/faaed0a5-1cbf-4218-8114-21a985dab993 /mnt
sudo btrfs subvolume list /mnt

sudo btrfs subvolume list -o /mnt/root | awk '{print $9}' | sort -r | while read -r subvol; do
  sudo btrfs subvolume delete "/mnt/$subvol"
done
sudo btrfs subvolume delete /mnt/root

sudo btrfs subvolume list -o /mnt/home | awk '{print $9}' | sort -r | while read -r subvol; do
  sudo btrfs subvolume delete "/mnt/$subvol"
done
sudo btrfs subvolume delete /mnt/home

sudo btrfs subvolume create /mnt/root
sudo btrfs subvolume create /mnt/home
sudo umount /mnt
```

Clean the separate ext4 `/boot` partition if Fedora is no longer needed:

```bash
sudo mount /dev/disk/by-uuid/94a02c88-01f7-4d05-9f22-459b0d6440d6 /mnt
sudo find /mnt -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +
sudo umount /mnt
```

Do not format the EFI System Partition unless you intentionally want to remove every UEFI bootloader on it. If Fedora is gone and you only want to remove old Fedora/NixOS bootloader files, remove those vendor directories:

```bash
sudo mount /dev/disk/by-uuid/801B-B94D /mnt
sudo rm -rf -- /mnt/EFI/fedora /mnt/EFI/nixos
sudo umount /mnt
```

## Install From The Public Flake

Boot from a NixOS ISO, connect to the network, and mount the target system under `/mnt`.

For the current layout:

```bash
sudo mount -o subvol=root,compress=zstd:1,ssd,discard=async /dev/disk/by-uuid/faaed0a5-1cbf-4218-8114-21a985dab993 /mnt
sudo mkdir -p /mnt/home /mnt/boot
sudo mount -o subvol=home,compress=zstd:1,ssd,discard=async /dev/disk/by-uuid/faaed0a5-1cbf-4218-8114-21a985dab993 /mnt/home
sudo mount /dev/disk/by-uuid/94a02c88-01f7-4d05-9f22-459b0d6440d6 /mnt/boot
sudo mkdir -p /mnt/boot/efi
sudo mount /dev/disk/by-uuid/801B-B94D /mnt/boot/efi
```

If you want encrypted secrets to be applied during the first install, copy the private age identity before running `nixos-install`:

```bash
sudo install -d -m 700 /mnt/var/lib/sops-nix
sudo install -m 600 ./keys.txt /mnt/var/lib/sops-nix/key.txt
```

Then install directly from GitHub:

```bash
sudo nixos-install --flake github:kontsevoye/nix/master#evkon-pc
```

Set the user password before rebooting:

```bash
sudo nixos-enter --root /mnt -c 'passwd evkon'
```

Then reboot:

```bash
sudo reboot
```

## Rebuild After Installation

After the system is installed, rebuild from the public GitHub flake with:

```bash
sudo nixos-rebuild switch --flake github:kontsevoye/nix/master#evkon-pc
```

If you have a local checkout at `/home/evkon/my-nix`, rebuild from the local checkout with:

```bash
sudo nixos-rebuild switch --flake /home/evkon/my-nix#evkon-pc
```

## Update Fast-Moving Apps

Google Chrome is installed through Home Manager from the separate `nixpkgs-chrome` flake input. This lets Chrome move faster than the main system `nixpkgs` input.
Telegram Desktop uses the same pattern through the separate `nixpkgs-telegram` flake input.

From a local checkout, update only the selected package source and switch the system:

```bash
nix flake update nixpkgs-chrome
sudo nixos-rebuild switch --flake .#evkon-pc
```

For Telegram:

```bash
nix flake update nixpkgs-telegram
sudo nixos-rebuild switch --flake .#evkon-pc
```

If rebuilding from `/home/evkon/my-nix`, run the same commands from that checkout and keep the explicit flake path:

```bash
cd /home/evkon/my-nix
nix flake update nixpkgs-chrome
sudo nixos-rebuild switch --flake /home/evkon/my-nix#evkon-pc
```

Codex is intentionally not installed from `nixpkgs`, because that package can lag behind the official CLI. The `evkon-pc` Home Manager profile provides a `codex-update` command that installs or updates `@openai/codex@latest` through npm.

Update Codex immediately:

```bash
codex-update
```

## Encrypted Secrets

`evkon-pc` uses `sops-nix` with an age identity at `/var/lib/sops-nix/key.txt`.
The public repository should contain only encrypted SOPS files, never plaintext private keys.

Put the private age identity on the installed system before running `nixos-rebuild`:

```bash
sudo install -d -m 700 /var/lib/sops-nix
sudo install -m 600 ./keys.txt /var/lib/sops-nix/key.txt
```

When installing from the NixOS ISO, copy it under `/mnt` before `nixos-install`:

```bash
sudo install -d -m 700 /mnt/var/lib/sops-nix
sudo install -m 600 ./keys.txt /mnt/var/lib/sops-nix/key.txt
```

Decrypt the secrets file into a local plaintext work file:

```bash
SOPS_AGE_KEY_FILE=./keys.txt sops --decrypt nixos/evkon-pc/secrets/evkon-pc.yaml > nixos/evkon-pc/secrets/evkon-pc.plain.yaml
chmod 600 nixos/evkon-pc/secrets/evkon-pc.plain.yaml
```

Edit that plaintext file, then re-encrypt it back:

```bash
$EDITOR nixos/evkon-pc/secrets/evkon-pc.plain.yaml
SOPS_AGE_KEY_FILE=./keys.txt sops --encrypt nixos/evkon-pc/secrets/evkon-pc.plain.yaml > nixos/evkon-pc/secrets/evkon-pc.yaml
grep -q 'ENC\[' nixos/evkon-pc/secrets/evkon-pc.yaml
rm -f nixos/evkon-pc/secrets/evkon-pc.plain.yaml
```

Optional managed SSH known hosts can be stored as `ssh-known_hosts` in the plaintext secrets file.
It is installed to `/home/evkon/.ssh/known_hosts.managed`; new hosts discovered by SSH still go to the mutable `/home/evkon/.ssh/known_hosts`.
Optional managed SSH host config can be stored as `ssh-config-managed`.
It is installed to `/home/evkon/.ssh/config.d/managed.conf`; `/home/evkon/.ssh/config` gets only `Include ~/.ssh/config.d/*.conf`.

## Flatpak Management

`nixos/evkon-pc/flatpaks.nix` declares the managed system Flatpak applications.
The `flatpak-managed-apps` systemd service adds Flathub, installs declared apps system-wide, updates them, removes system Flatpak apps not listed there, and removes unused runtimes.

## Validation

Evaluate the system derivation without building it:

```bash
nix eval --raw github:kontsevoye/nix/master#nixosConfigurations.evkon-pc.config.system.build.toplevel.drvPath
```

Evaluate the standalone Home Manager profile:

```bash
nix eval --raw 'github:kontsevoye/nix/master#homeConfigurations."evkon@evkon-pc".activationPackage.drvPath'
```
