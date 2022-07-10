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
        defaultText = "test";
      };

      cmd = mkOption {
        type = types.str;
        default = "${cfg.secrets.default-cmd} ${cfg.secrets.cmd-name-prefix}${config.name}";
        description = "Command to print the secret. E.g. `cat mysecretfile`";
        defaultText = "test";
      };

      path = mkOption {
        type = types.str;
        default = "${cfg.secrets.default-dir}/${config.name}";
        description = "Path to place the secret file";
        defaultText = "test";
      };

      mode = mkOption {
        type = types.str;
        default = "0400";
        description = "Unix permission";
        defaultText = "test";
      };

      owner = mkOption {
        type = types.str;
        default = "root";
        description = "Owner of the secret file";
        defaultText = "test";
      };

      group-name = mkOption {
        type = types.str;
        default = "root";
        description = "Group of the secret file";
        defaultText = "test";
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
        defaultText = "test";
      };

      cmd-name-prefix = mkOption {
        type = types.str;
        default = "";
        description = "Prefix to prepend to all name when passing to the cmd";
        defaultText = "test";
      };

      default-dir = mkOption {
        type = types.str;
        default = "/var/src/lollypops-secrets";
        description = "Path to place the secrets on the remote host if no alternative is specified";
        defaultText = "test";
      };

      files = mkOption {
        type = with types; attrsOf secret-file;
        default = { };
        description = "Attribute set specifying secrets to be deployed";
        defaultText = "test";
      };
    };

    deployment = {

      local-evaluation = mkOption {
        type = types.bool;
        default = false;
        description = "Evaluate locally instead of on the remote when rebuilding";
        defaultText = "test";
      };

      config-dir = mkOption {
        type = types.str;
        default = "/var/src/lollypops";
        description = "Path to place the configuration on the remote host";
        defaultText = "test";
      };

      host = mkOption {
        type = types.str;
        default = "${config.networking.hostName}";
        description = "Host to deploy to";
        defaultText = "test";
      };

      user = mkOption {
        type = types.str;
        default = "root";
        description = "User to deploy as";
        defaultText = "test";
      };
    };
  };

  config = {
     environment.systemPackages = with pkgs; [ rsync ];
  };

  meta = {
    maintainers = with lib.maintainers; [ pinpox ];
    buildDocsInSandbox = false;
  };

}
