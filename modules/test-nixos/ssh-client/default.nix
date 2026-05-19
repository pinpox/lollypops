# Module only used for tests
{
  config,
  lib,
  modulesPath,
  nodes,
  pkgs,
  ...
}:
let
  users = [
    "alice"
    "bob"
    "root"
  ];
in
{
  imports = [
    # Defines alice and bob users
    (modulesPath + "/../tests/common/user-account.nix")
  ];

  # Clients need the ssh binary to connect to the server
  environment.systemPackages = with pkgs; [
    openssh
  ];

  # Clients know the public key of the nodes, which is hardcoded
  programs.ssh.knownHosts = lib.mapAttrs (node: _: {
    publicKeyFile = ../ssh-server/keys/ssh_host_ed25519_key.pub;
  }) nodes;

  # Place SSH keys in /etc/ssh/keys/ as source files
  environment.etc = lib.foldl (
    acc: user:
    acc
    // {
      "ssh/keys/${user}.pub".source = ./keys/${user}.pub;
      "ssh/keys/${user}".source = ./keys/${user};
    }
  ) { } users;

  # Copy SSH keys to user home directories with proper ownership and permissions
  system.activationScripts.setupSshKeys = lib.stringAfter [ "users" ] (
    lib.concatMapStringsSep "\n" (
      user:
      let
        home = config.users.users.${user}.home;
        group = config.users.users.${user}.group;
      in
      ''
        mkdir -p ${home}/.ssh
        cp /etc/ssh/keys/${user} ${home}/.ssh/id_rsa
        cp /etc/ssh/keys/${user}.pub ${home}/.ssh/id_rsa.pub
        chown -R ${user}:${group} ${home}/.ssh
        chmod 700 ${home}/.ssh
        chmod 600 ${home}/.ssh/id_rsa
        chmod 644 ${home}/.ssh/id_rsa.pub
      ''
    ) users
  );
}
