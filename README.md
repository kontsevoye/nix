## Install

1. Install the nix package manager itself

```bash
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
```

2. Follow the [nix-darwin readme](DARWIN_README.md)
3. Follow the [home-manager readme](HOME_MANAGER_README.md)
4. Follow the [WSL readme](WSL_README.md)
5. Follow the [NixOS readme](NIXOS_README.md)

## Homelab certificate trust

The public root CA is tracked in [`shared/certificates/homelab-root-ca.crt`](shared/certificates/homelab-root-ca.crt). Both NixOS and the Mac Home Manager configuration use this single file. No certificate files from another checkout or private keys are needed to build these configurations. The private CA key stays outside this repository.

The certificate is `SynologyChatreyans Root CA`, valid until **2036-01-08**. Its SHA-256 fingerprint is:

```text
E2:E6:97:A3:DD:BC:D9:1B:5C:6B:9B:CA:29:02:74:1D:3E:A8:EA:62:5E:BC:68:52:47:E6:2E:BE:27:F4:FC:F2
```

For NixOS, include it in the system trust store. From a module under `nixos/<machine>/`:

```nix
security.pki.certificateFiles = [
  ../../shared/certificates/homelab-root-ca.crt
];
```

For Nix curl on the Mac, [`home-manager/machines/e.kontsevoy_at_e-kontsevoy-mac.nix`](home-manager/machines/e.kontsevoy_at_e-kontsevoy-mac.nix) builds a bundle containing the Mozilla public roots from `pkgs.cacert` plus this CA, then manages `~/.curlrc`. From a Home Manager module at the same directory depth:

```nix
{ pkgs, ... }:
let
  curlCacert = pkgs.cacert.override {
    blacklist = import ../../shared/certificates/emudhra-blacklist.nix;
  };
  curlCaBundle = pkgs.runCommand "curl-homelab-ca-bundle.pem" { } ''
    cat ${curlCacert}/etc/ssl/certs/ca-bundle.crt \
      ${../../shared/certificates/homelab-root-ca.crt} > "$out"
  '';
in
{
  home.file.".curlrc".text = ''
    cacert = "${curlCaBundle}"
  '';
}
```

This enables ordinary `curl https://boxctl.lan/` while preserving public HTTPS trust and certificate/hostname verification. It configures curl; it does not install a CA into the macOS Keychain or configure every TLS application. Future service certificates signed by this CA are trusted without adding each leaf certificate separately.

The bundle and curlrc are generated from this repository by Nix. Normal Home Manager activation installs the curlrc; there is no need to copy a bundle manually. Updating `pkgs.cacert` through the pinned Nixpkgs input updates the Mozilla roots on the next rebuild and activation.

## eMudhra CA mitigation (2026-10-21)

The [incident report and test endpoints](https://emudhra.we-have-a-problem.com/)
identify compromised intermediates chaining to `emSign ECC Root CA - G3` and
`AAA Certificate Services` (NSS label: `Comodo AAA Services root`).
[`shared/certificates/emudhra-blacklist.nix`](shared/certificates/emudhra-blacklist.nix)
excludes both roots from the system PEM bundles on Darwin, NixOS and WSL, and
from the Mac's separate curl bundle. The homelab CA remains trusted.

Darwin activation also filters Apple's `/etc/ssl/cert.pem`, used by
`/usr/bin/curl -q`. It saves the original as `/etc/ssl/cert.pem.before-emudhra`
before the first change and reapplies the filter on subsequent activations,
including after macOS updates. This does not modify the macOS Keychain.

Apply on the Mac:

```bash
sudo -H ./scripts/darwin-switch
```

After activation, both commands below must fail with curl error **60**:

```bash
curl https://dv-g3b-emudhra.we-have-a-problem.com/
/usr/bin/curl -q https://dv-g3b-aaa-emudhra.we-have-a-problem.com/
```

Check normal public HTTPS and `curl https://boxctl.lan/` as well. Applications
with embedded CA stores need their own upstream updates. Removing these roots
also rejects legitimate chains that depend exclusively on them.

To undo the mitigation, remove the blacklist settings and Darwin filter block,
rebuild, and restore Apple's saved file with
`sudo cp -p /etc/ssl/cert.pem.before-emudhra /etc/ssl/cert.pem`. If macOS has
updated its bundle since the backup, prefer its current bundle instead of
restoring an older copy.

## Collect garbage 

```bash
nix-collect-garbage -d
```

## Acknowledgments

- [Newbies friendly introduction to nix](https://zero-to-nix.com/)
- [Article about nix+darwin+homemanager](https://davi.sh/til/nix/nix-macos-setup/)
- [nix-darwin](https://github.com/LnL7/nix-darwin)
- [nix-darwin options](https://daiderd.com/nix-darwin/manual/index.html#sec-options)
- [home-manager](https://github.com/nix-community/home-manager)
- [home-manager manual](https://nix-community.github.io/home-manager/)
- [home-manager options](https://home-manager-options.extranix.com/)
