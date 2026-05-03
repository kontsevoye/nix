{
  config,
  lib,
  pkgs,
  ...
}:

let
  flathubRemote = "https://dl.flathub.org/repo/flathub.flatpakrepo";
  managedApps = [
    "com.github.tchx84.Flatseal"
    "io.github.giantpinkrobots.flatsweep"
    "io.github.sigmasd.stimulator"
    "us.zoom.Zoom"
  ];
  flatpakOverrides = {
    "us.zoom.Zoom" = [
      "--nosocket=wayland"
      "--socket=x11"
      "--env=QT_QPA_PLATFORM=xcb"
    ];
  };
  managedAppsFile = pkgs.writeText "evkon-pc-flatpak-apps" (lib.concatLines managedApps);
  flatpakOverridesFile = pkgs.writeText "evkon-pc-flatpak-overrides" (
    builtins.toJSON flatpakOverrides
  );
  flatpakOverrideScript = lib.concatStringsSep "\n" (
    lib.mapAttrsToList (appId: args: ''
      if [ "$app" = ${lib.escapeShellArg appId} ]; then
        flatpak override --system ${lib.concatMapStringsSep " " lib.escapeShellArg args} "$app"
      fi
    '') flatpakOverrides
  );
in
{
  services.flatpak.enable = true;

  environment.etc."flatpak/managed-apps".source = managedAppsFile;

  systemd.services.flatpak-managed-apps = lib.mkIf config.services.flatpak.enable {
    description = "Install declared Flatpak applications";
    wantedBy = [ "multi-user.target" ];
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    restartTriggers = [
      managedAppsFile
      flatpakOverridesFile
    ];
    path = with pkgs; [
      coreutils
      flatpak
      gnugrep
    ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };

    script = ''
      set -euo pipefail

      flatpak remote-add --system --if-not-exists flathub ${lib.escapeShellArg flathubRemote}

      while IFS= read -r app; do
        [ -n "$app" ] || continue

        if flatpak info --system "$app" >/dev/null 2>&1; then
          flatpak update --system -y "$app"
        else
          flatpak install --system -y flathub "$app"
        fi

        ${flatpakOverrideScript}
      done < ${managedAppsFile}

      flatpak list --system --app --columns=application | while IFS= read -r installed; do
        [ -n "$installed" ] || continue

        if ! grep -Fxq "$installed" ${managedAppsFile}; then
          flatpak uninstall --system -y "$installed"
        fi
      done

      flatpak uninstall --system --unused -y || true
    '';
  };
}
