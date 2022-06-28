{ config, pkgs, lib, ... }:

with lib;

let
  cfg = config.lollypops;

  secret-file = types.submodule ({ config, ... }: {
    options = {

      name = mkOption {
        type = types.str;
        default = config._module.args.name;
        description = "Name of the secret";
      };

      cmd = mkOption {
        type = types.str;
        default = "${pkgs.pass}/bin/pass ${config.name}";
        description = "Command to print the secret. E.g. `cat mysecretfile`";
      };

      path = mkOption {
        type = types.str;
        default = "/run/keys/${config.name}";
        description = "Path to place the secret file";
      };

      mode = mkOption {
        type = types.str;
        default = "0400";
        description = "Unix permission";
      };

      owner = mkOption {
        type = types.str;
        default = "root";
        description = "Owner of the secret file";
      };

      group-name = mkOption {
        type = types.str;
        default = "root";
        description = "Group of the secret file";
      };
    };
  });
in
{

  options.lollypops = {
    secrets = {
      files = mkOption {
        type = with types; attrsOf secret-file;
        default = { };
        description = "Attribute set specifying secrets to be deployed";
      };
    };

    deployment = {

      config-dir = mkOption {
        type = types.str;
        default = "/var/src/lollypops";
        description = "Path to place the configuration on the remote host";
      };

      host = mkOption {
        type = types.str;
        default = "${config.networking.hostName}";
        description = "Host to deploy to";
      };

      user = mkOption {
        type = types.str;
        default = "root";
        description = "User to deploy as";
      };
    };
  };
  # config = { };
}
