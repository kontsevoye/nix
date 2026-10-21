[
  (final: prev: {
    bitwarden-desktop = prev.bitwarden-desktop.override {
      electron_43 = final.electron_43-bin;
    };
    ghostty-pr-9857 = final.callPackage ../packages/ghostty-pr-9857.nix { };
  })
]
