## Install

```bash
# run inside current directory or change "." to the actual location
sudo nixos-rebuild switch --flake .
```

## Update

### Update dependencies

```bash
# run inside current directory or change "." to the actual location
nix flake update .
```

### Rebuild configuration after changes

```bash
# run inside current directory or change "." to the actual location
sudo nixos-rebuild switch --flake .
```

### Collect garbage

```bash
sudo nix-collect-garbage -d
```

