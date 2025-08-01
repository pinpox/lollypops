{ lib, modulesPath, ... }:
{
  imports = [
    # Defines alice and bob users
    (modulesPath + "/../tests/common/user-account.nix")
  ];

  # Servers have sshd
  services.openssh.enable = true;

  # Hardcoded keys, for easier testing
  environment.etc."ssh/ssh_host_ed25519_key" = {
    mode = "u=rw,go=";
    source = ./keys/ssh_host_ed25519_key;
  };
  environment.etc."ssh/ssh_host_ed25519_key.pub".source = ./keys/ssh_host_ed25519_key.pub;

  # Each user in the server has its own SSH client key authorized
  users.users = lib.genAttrs [ "alice" "bob" "root" ] (user: {
    openssh.authorizedKeys.keyFiles = [ ../ssh-client/keys/${user}.pub ];
  });
}
