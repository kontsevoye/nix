{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-wsl = {
      url = "github:nix-community/NixOS-WSL/main";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    darwin = {
      url = "github:lnl7/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/0.1";
  };

  outputs =
    {
      nixpkgs,
      home-manager,
      nixos-wsl,
      darwin,
      determinate,
      ...
    }:
    let
      mkHome =
        home: system: extraModules:
        home-manager.lib.homeManagerConfiguration {
          pkgs = import nixpkgs { system = system; };
          modules = [
            ./home-manager/default.nix
            home
          ] ++ extraModules;
        };
    in
    {
      homeConfigurations = {
        "e.kontsevoy@e-kontsevoy-mac" =
          mkHome ./home-manager/machines/e.kontsevoy_at_e-kontsevoy-mac.nix "aarch64-darwin"
            [ ];
        "e.kontsevoy@nixos" =
          mkHome ./home-manager/machines/e.kontsevoy_at_nixos_aka_mac_vm.nix "aarch64-linux"
            [ ];
        "nixos@nixos" = mkHome ./home-manager/machines/nixos_at_nixos_aka_wsl.nix "x86_64-linux" [
          ./home-manager/gui-apps.nix
          ./home-manager/wsl-gui-apps.nix
        ];
        "deck@steamdeck" = mkHome ./home-manager/machines/deck_at_steamdeck.nix "x86_64-linux" [
          ./home-manager/gui-apps.nix
        ];
      };
      nixosConfigurations = {
        nixos = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            nixos-wsl.nixosModules.default
            ./wsl/default.nix
          ];
        };
      };
      darwinConfigurations = {
        "e-kontsevoy-mac" = darwin.lib.darwinSystem {
          system = "aarch64-darwin";
          modules = [ 
            determinate.darwinModules.default
            ./darwin/default.nix 
          ];
        };
      };
    };
}
