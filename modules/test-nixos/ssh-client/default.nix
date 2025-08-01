# Module only used for tests
{
  config,
  lib,
  modulesPath,
  nodes,
  pkgs,
  ...
}:
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

  # Provide ssh key files that have appropriate permissions
  environment.etc =
    lib.foldl
      (
        acc: user:
        acc
        // {
          "ssh/keys/${user}.pub".source = ./keys/${user}.pub;
          "ssh/keys/${user}" = {
            inherit user;
            mode = "u=rw,go=";
            source = ./keys/${user};
          };
        }
      )
      { }
      [
        "alice"
        "bob"
        "root"
      ];
}
