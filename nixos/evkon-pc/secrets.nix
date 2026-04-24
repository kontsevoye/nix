{
  config,
  lib,
  pkgs,
  ...
}:

let
  user = "evkon";
  group = "users";
  homeDirectory = "/home/${user}";
  secretsFile = ./secrets/evkon-pc.yaml;
  secretsEnabled = builtins.pathExists secretsFile;

  sshKeyNames = [
    "bss_sftp_key"
    "cobase_connector_key"
    "digitalgoods_deploy_key"
    "id_rsa"
    "id_vpn_converter"
    "nbgoods_deploy_key"
    "sber_id_ed25519"
  ];

  sshSecretName = name: "ssh-${name}";
  sshSecrets = lib.listToAttrs (
    map (name: {
      name = sshSecretName name;
      value = {
        sopsFile = secretsFile;
        mode = "0400";
      };
    }) sshKeyNames
  );

  installSshKey =
    name:
    let
      secretName = sshSecretName name;
      sourcePath = config.sops.secrets.${secretName}.path;
      targetPath = "${homeDirectory}/.ssh/${name}";
    in
    ''
      if [ -s ${lib.escapeShellArg sourcePath} ]; then
        ${pkgs.coreutils}/bin/install -m 0600 -o ${user} -g ${group} ${lib.escapeShellArg sourcePath} ${lib.escapeShellArg targetPath}
      fi
    '';

  importGpgKey =
    secretName:
    let
      sourcePath = config.sops.secrets.${secretName}.path;
    in
    ''
      if [ -s ${lib.escapeShellArg sourcePath} ]; then
        ${pkgs.coreutils}/bin/cat ${lib.escapeShellArg sourcePath} | ${pkgs.util-linux}/bin/runuser -u ${user} -- ${pkgs.gnupg24}/bin/gpg --batch --import -
      fi
    '';

  installKnownHosts =
    let
      sourcePath = config.sops.secrets."ssh-known_hosts".path;
      targetPath = "${homeDirectory}/.ssh/known_hosts.managed";
    in
    ''
      if [ -s ${lib.escapeShellArg sourcePath} ]; then
        ${pkgs.coreutils}/bin/install -m 0644 -o ${user} -g ${group} ${lib.escapeShellArg sourcePath} ${lib.escapeShellArg targetPath}
      fi
    '';

  installSshConfig =
    let
      sourcePath = config.sops.secrets."ssh-config-managed".path;
      configDirectory = "${homeDirectory}/.ssh/config.d";
      targetPath = "${configDirectory}/managed.conf";
      userConfigPath = "${homeDirectory}/.ssh/config";
      includeLine = "Include ~/.ssh/config.d/*.conf";
    in
    ''
      ${pkgs.coreutils}/bin/install -d -m 0700 -o ${user} -g ${group} ${lib.escapeShellArg configDirectory}
      if [ -s ${lib.escapeShellArg sourcePath} ]; then
        ${pkgs.coreutils}/bin/install -m 0600 -o ${user} -g ${group} ${lib.escapeShellArg sourcePath} ${lib.escapeShellArg targetPath}
      fi
      if [ ! -e ${lib.escapeShellArg userConfigPath} ]; then
        ${pkgs.coreutils}/bin/install -m 0600 -o ${user} -g ${group} /dev/null ${lib.escapeShellArg userConfigPath}
      fi
      if ! ${pkgs.gnugrep}/bin/grep -qxF ${lib.escapeShellArg includeLine} ${lib.escapeShellArg userConfigPath}; then
        ${pkgs.coreutils}/bin/printf '%s\n' ${lib.escapeShellArg includeLine} >> ${lib.escapeShellArg userConfigPath}
        ${pkgs.coreutils}/bin/chown ${user}:${group} ${lib.escapeShellArg userConfigPath}
        ${pkgs.coreutils}/bin/chmod 0600 ${lib.escapeShellArg userConfigPath}
      fi
    '';
in
{
  sops.age.keyFile = "/var/lib/sops-nix/key.txt";

  sops.secrets = lib.mkIf secretsEnabled (
    sshSecrets
    // {
      "gpg-private-rsa" = {
        sopsFile = secretsFile;
        mode = "0400";
      };
      "gpg-private-ed25519" = {
        sopsFile = secretsFile;
        mode = "0400";
      };
      "ssh-known_hosts" = {
        sopsFile = secretsFile;
        mode = "0400";
      };
      "ssh-config-managed" = {
        sopsFile = secretsFile;
        mode = "0400";
      };
    }
  );

  programs.ssh.extraConfig = ''
    GlobalKnownHostsFile ${homeDirectory}/.ssh/known_hosts.managed /etc/ssh/ssh_known_hosts
    UserKnownHostsFile ${homeDirectory}/.ssh/known_hosts
  '';

  system.activationScripts.installEvkonSecrets = lib.mkIf secretsEnabled {
    deps = [
      "setupSecrets"
      "users"
    ];
    text = ''
      ${pkgs.coreutils}/bin/install -d -m 0700 -o ${user} -g ${group} ${homeDirectory}/.ssh
      ${lib.concatMapStringsSep "\n" installSshKey sshKeyNames}
      ${installKnownHosts}
      ${installSshConfig}

      ${pkgs.coreutils}/bin/install -d -m 0700 -o ${user} -g ${group} ${homeDirectory}/.gnupg
      ${importGpgKey "gpg-private-rsa"}
      ${importGpgKey "gpg-private-ed25519"}
    '';
  };
}
