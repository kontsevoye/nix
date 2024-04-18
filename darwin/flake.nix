{
  description = "Darwin configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    # darwin.url = "github:lnl7/nix-darwin";
    # https://github.com/LnL7/nix-darwin/pull/932
    # https://github.com/NixOS/nixpkgs/pull/303841
    darwin.url = "github:wegank/nix-darwin/mddoc-remove";
    darwin.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs@{ nixpkgs, darwin, ... }: {
    darwinConfigurations = {
      "e-kontsevoy-mac" = darwin.lib.darwinSystem {
        system = "aarch64-darwin";
        modules = [ ./darwin.nix ];
      };
    };
  };
}
