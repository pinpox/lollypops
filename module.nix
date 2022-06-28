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
        default = "${cfg.secrets.default-dir-todo}/${config.name}";
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

      secrets-dir = mkOption {
        type = types.str;
        default = "/var/src/lollypops-secrets";
        description = "Path to place the configuration on the remote host";
      };

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


  config = lib.mkIf (cfg.secrets.files != { }) {
    system.activationScripts.setup-secrets =
      let
        files =
          unique (map (flip removeAttrs [ "_module" ]) (attrValues cfg.secrets.files));
        script = ''
          echo setting up secrets...
          mkdir -p /run/keys -m 0750
          chown root:keys /run/keys
          ${concatMapStringsSep "\n" (file: ''
            ${pkgs.coreutils}/bin/install \
              -D \
              --compare \
              --verbose \
              --mode=${lib.escapeShellArg file.mode} \
              --owner=${lib.escapeShellArg file.owner} \
              --group=${lib.escapeShellArg file.group-name} \
              ${lib.escapeShellArg file.source-path} \
              ${lib.escapeShellArg file.path} \
            || echo "failed to copy ${file.source-path} to ${file.path}"
          '') files}
        '';
      in
      stringAfter [ "users" "groups" ]
        "source ${pkgs.writeText "setup-secrets.sh" script}";
  };
}
