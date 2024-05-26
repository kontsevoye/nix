## Install

```bash
# run inside current directory or change "." to the actual location
nix --extra-experimental-features "nix-command flakes" run home-manager/master -- switch --flake .
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
home-manager switch --flake .
```

### Collect garbage

```bash
home-manager expire-generations "-1 days"
```
