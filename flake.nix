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
  };

  outputs =
    inputs@{
      nixpkgs,
      home-manager,
      nixos-wsl,
      darwin,
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
          ]
          ++ extraModules;
        };
      systems = [
        "aarch64-darwin"
        "aarch64-linux"
        "x86_64-darwin"
        "x86_64-linux"
      ];
      forEachSystem =
        function:
        nixpkgs.lib.genAttrs systems (
          system:
          function {
            inherit system;
            pkgs = nixpkgs.legacyPackages.${system};
          }
        );
    in
    {
      formatter = forEachSystem ({ pkgs, ... }: pkgs.nixfmt-rfc-style);
      homeConfigurations = {
        "e.kontsevoy@nixos" =
          mkHome ./home-manager/machines/e.kontsevoy_at_nixos_aka_mac_vm.nix "aarch64-linux"
            [ ];
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
            home-manager.nixosModules.home-manager
            {
              home-manager.users.nixos = {
                imports = [
                  ./home-manager/machines/nixos_at_nixos_aka_wsl.nix
                  ./home-manager/default.nix
                  ./home-manager/gui-apps.nix
                  ./home-manager/wsl-gui-apps.nix
                ];
              };
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
            }
          ];
        };
      };
      darwinConfigurations = {
        "e-kontsevoy-mac" = darwin.lib.darwinSystem {
          system = "aarch64-darwin";
          modules = [
            ./darwin/default.nix
            home-manager.darwinModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
            }
          ];
        };
      };
    };
}
