{
  description = "Home Manager configuration of e.kontsevoy";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, home-manager, ... }:
  {
    homeConfigurations = {
      "e.kontsevoy@e-kontsevoy-mac" = home-manager.lib.homeManagerConfiguration ({
        modules = [ 
          ./home.nix
          {
            home = {
              username = "e.kontsevoy";
              homeDirectory = "/Users/e.kontsevoy";
            };
          }
        ];
        pkgs = import nixpkgs {
          system = "aarch64-darwin";
        };
      });
      "e.kontsevoy@nixos" = home-manager.lib.homeManagerConfiguration ({
        modules = [ 
          ./home.nix
          {
            home = {
              username = "e.kontsevoy";
              homeDirectory = "/home/e.kontsevoy";
            };
          }
        ];
        pkgs = import nixpkgs {
          system = "aarch64-linux";
        };
      });
      "nixos@nixos" = home-manager.lib.homeManagerConfiguration ({
        modules = [
          ./home.nix
          ./home-gui.nix
          {
            home = {
              username = "nixos";
              homeDirectory = "/home/nixos";
            };
          }
        ];
        pkgs = import nixpkgs {
          system = "x86_64-linux";
        };
      });
      "deck@steamdeck" = home-manager.lib.homeManagerConfiguration ({
        modules = [
          ./home.nix
          ./home-gui.nix
          {
            home = {
              username = "deck";
              homeDirectory = "/home/deck";
            };
          }
        ];
        pkgs = import nixpkgs {
          system = "x86_64-linux";
        };
      });
    };
  };
}
