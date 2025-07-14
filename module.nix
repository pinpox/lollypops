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

      vault-name = mkOption {
        type = types.str;
        default = lib.concatStrings [cfg.secrets.cmd-name-prefix config.name];
        description = "Name of the secret in the vault";
        defaultText = "<cmd-name-prefix><name>";
      };

      cmd = mkOption {
        type = types.str;
        default = "${cfg.secrets.default-cmd} ${config.vault-name}";
        description = "Command to print the secret. E.g. `cat mysecretfile`";
        defaultText = "<default-cmd> <vault-name>";
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
  key = "github:pinpox/lollypops#nixosModules.default";

  config = {

    assertions = [
      {
        assertion = !(cfg.deployment.group != "default" && cfg.deployment.groups != [ "default" ]);
        message = "Only one of options `group` (deprecated) or `groups` can be set";
      }
    ];

  };

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
        example = "/run/lollypops-secrets";
        description = ''
          Path to place the secrets on the remote host if no alternative is specified.

          You can use a path under `/run/`, like `/run/lollypops-secrets`, if you want
          the secrets to be volatile and not persist across reboots.
        '';
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

      deploy-method = mkOption {
        type = types.enum [ "copy" "archive" ];
        default = "copy";
        description = ''
          Method for copying flake to the remote. Using the default (`copy`) will
          only deploy the flake itself, while `archive` deploys the flake and
          all it's inputs to the remote machine. This is slower when deploying
          from a connection with slow upload speed, but allows using inputs
          which are not accessible from the remote.

          When using `copy` all inputs of the flake will be substituted or
          pulled from configured caches.
        '';
      };

      config-dir = mkOption {
        type = types.str;
        default = "/var/src/lollypops";
        description = "Path to place the configuration on the remote host";
      };

      group = mkOption {
        type = types.str;
        default = "default";
        description = ''
          Deprecated - use `groups` instead, where multiple group names can be specified.
          Group name for the host, used to perform actions against a group of servers
        '';
      };

      groups = mkOption {
        type = types.listOf types.str;
        default = [ "default" ];
        description = "List of group names for the host, used to perform actions against a group of servers";
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

    tasks = mkOption {
      type = types.listOf types.str;
      default = [ "deploy-flake" "deploy-secrets" "rebuild" ];
      description = "The list of tasks to run for each host.";
    };

    extraTasks = mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          dir = mkOption {
            type = types.either types.path types.str;
            default = ".";
            description = "Directory in which the task should run.";
          };
          deps = mkOption {
            type = types.listOf types.str;
            default = [ ];
            description = "Dependencies for the task.";
          };
          desc = mkOption {
            type = types.str;
            description = "Description for the task.";
          };
          cmds = mkOption {
            type = types.listOf types.str;
            description = "Commands for the task.";
          };
        };
      });
      default = { };
      description = ''
        Extra tasks to run for the host. If any are defined with the same name as the default tasks
        (<literal>deploy-secrets</literal>, <literal>rebuild</literal>, <literal>deploy-flake</literal>)
        the original tasks will be overriden.
      '';

    };
  };
}
