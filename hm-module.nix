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
        default = "${cfg.secrets.default-user}";
        description = "Owner of the secret file";
      };

      group-name = mkOption {
        type = types.str;
        default = "users";
        description = "Group of the secret file";
      };
    };
  });
in
{
  key = "github:pinpox/lollypops#hmModule";

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
        default = "${config.home.homeDirectory}/lollypops-secrets";
        description = "Path to place the secrets on the remote host if no alternative is specified";
      };

      default-user = mkOption {
        type = types.str;
        default = config.home.username;
        visible = false;
        readOnly = true;
      };

      files = mkOption {
        type = with types; attrsOf secret-file;
        default = { };
        description = "Attribute set specifying secrets to be deployed";
      };
    };
  };

  # config = { };
}
