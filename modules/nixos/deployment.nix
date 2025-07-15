{
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (lib) mkOption types;
  cfg = config.lollypops.deployment;
in
{
  key = "github:pinpox/lollypops#modules.nixos.deployment";

  options.lollypops.deployment = {

    local-evaluation = mkOption {
      type = types.bool;
      default = false;
      description = "Evaluate locally instead of on the remote when rebuilding";
    };

    deploy-method = mkOption {
      type = types.enum [
        "copy"
        "archive"
      ];
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
      description = "Group name for the host, used to perform actions against a group of servers";
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
        default = [ ];
        example = [ "--user=user" ];
        description = "Options to pass to the configured sudo command";
      };
    };

    ssh = {
      command = mkOption {
        type = types.str;
        default = "ssh";
        description = ''
          Local SSH binary to use for remote connections.

          The default value just uses the locally available `ssh` command.
        '';
      };

      opts = mkOption {
        type = types.listOf types.str;
        default = lib.optionals (cfg.ssh.user != "") [
          "-l"
          cfg.ssh.user
        ];
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
        default = "";
        description = ''
          Remote user to deploy as.

          Leave empty to use the current user.
        '';
      };

      login = mkOption {
        type = types.str;
        readOnly = true;
        default = "${cfg.ssh.command} ${pkgs.lib.concatMapStringsSep " " lib.escapeShellArg cfg.ssh.opts} ${lib.escapeShellArg cfg.ssh.host}";
        description = ''
          SSH login command, combining the SSH binary, options and host.

          This is used to run commands on the remote server. Also you can use it
          to connect to the remote server interactively, e.g.:

          ```shell
          nix run .#nixosConfigurations.<hostName>.lollypops.deployment.ssh.login
          ```
        '';
      };

      run = mkOption {
        type = types.str;
        default = "${cfg.ssh.login} -- ${cfg.ssh.command}";
        description = "Full command to run on the remote server";
      };
    };
  };
}
