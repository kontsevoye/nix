{
  description = "Personal Nix configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-chrome.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-telegram.url = "github:nixos/nixpkgs/nixos-unstable";
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
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
    determinate-nix.url = "github:DeterminateSystems/nix-src/v3.22.3";
    nix-rosetta-builder = {
      url = "github:cpick/nix-rosetta-builder";
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
      overlays = import ./shared/overlays.nix;
      permittedInsecurePackages = import ./shared/permitted-insecure-packages.nix;
      mkHome =
        home: system: extraModules:
        home-manager.lib.homeManagerConfiguration {
          pkgs = import nixpkgs {
            system = system;
            inherit overlays;
            config = {
              allowUnfree = true;
              inherit permittedInsecurePackages;
            };
          };
          extraSpecialArgs = { inherit inputs; };
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
      # Temporary, cached ARM Linux builder used only by scripts/darwin-switch.
      # Keep guest settings unchanged so it can bootstrap without a Linux builder.
      packages.aarch64-darwin.linux-builder-bootstrap =
        (nixpkgs.legacyPackages.aarch64-darwin.darwin.linux-builder.override {
          modules = [
            ({ lib, ... }: {
              virtualisation.forwardPorts = lib.mkForce [
                {
                  from = "host";
                  host.address = "127.0.0.1";
                  host.port = 31022;
                  guest.port = 22;
                }
              ];
            })
          ];
        }).run-builder;

      formatter = forEachSystem ({ pkgs, ... }: pkgs.nixfmt);
      devShells = forEachSystem (
        { pkgs, ... }:
        {
          default = pkgs.mkShell {
            packages = with pkgs; [
              nixfmt
              nil
            ];
          };
        }
      );
      homeConfigurations = {
        "e.kontsevoy@nixos" =
          mkHome ./home-manager/machines/e.kontsevoy_at_nixos_aka_mac_vm.nix "aarch64-linux"
            [ ];
        "deck@steamdeck" = mkHome ./home-manager/machines/deck_at_steamdeck.nix "x86_64-linux" [
          ./home-manager/gui-apps.nix
        ];
        "evkon@evkon-pc" = mkHome ./home-manager/machines/evkon_at_evkon_pc.nix "x86_64-linux" [ ];
      };
      nixosConfigurations = {
        "evkon-pc" = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            ./nixos/evkon-pc
            inputs.sops-nix.nixosModules.sops
            home-manager.nixosModules.home-manager
            {
              home-manager.users.evkon = {
                imports = [
                  ./home-manager/default.nix
                  ./home-manager/machines/evkon_at_evkon_pc.nix
                ];
              };
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.extraSpecialArgs = { inherit inputs; };
            }
          ];
        };
        nixos = nixpkgs.lib.nixosSystem {
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
          specialArgs = { inherit inputs; };
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
