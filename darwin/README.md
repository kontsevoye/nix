## Install

```bash
# run inside current directory or change "." to the actual location
nix --extra-experimental-features "nix-command flakes" run nix-darwin -- switch --flake .
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
darwin-rebuild switch --flake .
```
