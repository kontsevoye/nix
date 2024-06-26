## Install

1. Install the nix package manager itself

```bash
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
```

2. Follow the [nix-darwin readme](DARWIN_README.md)
3. Follow the [home-manager readme](HOME_MANAGER_README.md)
4. Follow the [WSL readme](WSL_README.md)

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

