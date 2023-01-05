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
        defaultText = "<name>";
      };

      cmd = mkOption {
        type = types.str;
        default = "${cfg.secrets.default-cmd} ${cfg.secrets.cmd-name-prefix}${config.name}";
        description = "Command to print the secret. E.g. `cat mysecretfile`";
        defaultText = "<default-cmd> <cmd-name-prefix><name>";
      };

      path = mkOption {
        type = types.str;
        default = "${cfg.secrets.default-dir}/${config.name}";
        description = "Path to place the secret file";
        defaultText = "<default-dir>/<name>";
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

      default-cmd = mkOption {
        type = types.str;
        default = "${pkgs.pass}/bin/pass";
        description = "Default command to retrieve passwords. Will be passed the name as parameter";
        defaultText = "\${pkgs.pass}/bin/pass";
      };

      cmd-name-prefix = mkOption {
        type = types.str;
        default = "";
        description = "Prefix to prepend to all name when passing to the cmd";
      };

      default-dir = mkOption {
        type = types.str;
        default = "/var/src/lollypops-secrets";
        description = "Path to place the secrets on the remote host if no alternative is specified";
      };

      files = mkOption {
        type = with types; attrsOf secret-file;
        default = { };
        description = "Attribute set specifying secrets to be deployed";
      };
    };

    deployment = {

      local-evaluation = mkOption {
        type = types.bool;
        default = false;
        description = "Evaluate locally instead of on the remote when rebuilding";
      };

      config-dir = mkOption {
        type = types.str;
        default = "/var/src/lollypops";
        description = "Path to place the configuration on the remote host";
      };

      sudo = {

        enable = mkOption {
          type = types.bool;
          default = false;
          description = "Enables the use of sudo for deployment on remote servers";
        };

        command = mkOption {
          type = types.str;
          default = "sudo";
          description = "Command to run for permission elevation";
        };

        opts = mkOption {
          type = types.listOf types.str;
          default = [ "" ];
          example = [ "--user=user" ];
          description = "Options to pass to the configured sudo command";
        };
      };

      ssh = {

        command = mkOption {
          type = types.str;
          default = "ssh";
          description = "Command to run for connection to another server";
        };

        opts = mkOption {
          type = types.listOf types.str;
          default = [ "" ];
          example = [ "-A" ];
          description = "Options to pass to the configured SSH command";
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
  };

  config = {
    environment.systemPackages = with pkgs; [ rsync ];
  };
}
