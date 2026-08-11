[
  (final: prev: {
    bitwarden-desktop = prev.bitwarden-desktop.override {
      electron_39 = final.electron_39-bin;
    };
    ghostty-pr-9857 = final.callPackage ../packages/ghostty-pr-9857.nix { };
  })
]
