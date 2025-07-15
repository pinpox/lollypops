{
  lib,
  ...
}:
let
  inherit (lib) mkOption types;
in
{
  key = "github:pinpox/lollypops#modules.nixos.tasks";

  options.lollypops = {

    tasks = mkOption {
      type = types.listOf types.str;
      default = [
        "deploy-flake"
        "deploy-secrets"
        "rebuild"
      ];
      description = "The list of tasks to run for each host.";
    };

    extraTasks = mkOption {
      type = types.attrsOf (
        types.submodule {
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
        }
      );
      default = { };
      description = ''
        Extra tasks to run for the host. If any are defined with the same name as the default tasks
        (<literal>deploy-secrets</literal>, <literal>rebuild</literal>, <literal>deploy-flake</literal>)
        the original tasks will be overriden.
      '';

    };
  };
}
