{
  description = "Lollypops - Lollypop Operations Deployment Tool";

  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  };

  outputs = { self, ... }@inputs:
    with inputs;
    {
      nixosModules.lollypops = import ./module.nix;
      nixosModules.default = self.nixosModules.lollypops;

      hmModule = import ./hm-module.nix;

    } //

    # TODO test/add other plattforms
    # (flake-utils.lib.eachDefaultSystem)
    (flake-utils.lib.eachSystem (flake-utils.lib.defaultSystems ++ [ "aarch64-darwin" ]))
      (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        rec {
          # Allow custom packages to be run using `nix run`
          apps =
            let

              mkSeclistUser = c: [
                ''
                  echo '${builtins.toString (builtins.attrNames c)}: ${builtins.typeOf c}'
                  echo '${builtins.toString (builtins.attrNames c.pinpox)}'
                ''
              ];
              # pkgs.lib.lists.flatten (map
              #   (x: [
              #     "echo 'Deploying ${x.name} to ${pkgs.lib.escapeShellArg x.path}'"
              #   ])
              #   (builtins.attrValues config.lollypops.secrets.files));
              mkSeclist = config: pkgs.lib.lists.flatten (map
                (x: [
                  "echo 'Deploying ${x.name} to ${pkgs.lib.escapeShellArg x.path}'"
                  # Create parent directory if it does not exist
                  ''
                    set -o pipefail -e; ssh {{.REMOTE_USER}}@{{.REMOTE_HOST}} 'umask 077; mkdir -p "$(dirname ${pkgs.lib.escapeShellArg x.path})"'
                  ''
                  # Copy file
                  ''
                    set -o pipefail -e; ${x.cmd} | ssh {{.REMOTE_USER}}@{{.REMOTE_HOST}} "umask 077; cat > ${pkgs.lib.escapeShellArg x.path}"
                  ''
                  # # Set group and owner
                  ''
                    set -o pipefail -e; ssh {{.REMOTE_USER}}@{{.REMOTE_HOST}} "chown ${x.owner}:${x.group-name} ${pkgs.lib.escapeShellArg x.path}"
                  ''
                ])
                (builtins.attrValues config.lollypops.secrets.files));

            in
            {

              default = { configFlake, ... }:
                let

                  mkTaskFileForHost = hostName: hostConfig: pkgs.writeText "CommonTasks.yml"
                    (builtins.toJSON {
                      version = "3";
                      output = "prefixed";

                      vars = with hostConfig.config.lollypops; {
                        REMOTE_USER = deployment.user;
                        REMOTE_HOST = deployment.host;
                        REBUILD_ACTION = ''{{default "switch" .REBUILD_ACTION}}'';
                        REMOTE_CONFIG_DIR = deployment.config-dir;
                        LOCAL_FLAKE_SOURCE = configFlake;
                        HOSTNAME = hostName;
                      };

                      tasks = {

                        check-vars.preconditions = [{
                          sh = ''[ ! -z "{{.HOSTNAME}}" ]'';
                          msg = "HOSTNAME not set: {{.HOSTNAME}}";
                        }];

                        deploy-secrets = {
                          deps = [ "check-vars" ];

                          desc = "Deploy secrets to: ${hostName}";

                          cmds = [
                            ''echo "Deploying secrets to: {{.HOSTNAME}}"''
                          ]
                          # ++ mkSeclist hostConfig.config
                          ++ mkSeclistUser hostConfig.config.home-manager.users;

                          # lollypops.secrets.files."usertest" = {};

                          # home-manager.users.pinpox = flake-self.homeConfigurations.desktop;

                        };

                        rebuild = {
                          dir = self;

                          desc = "Rebuild configuration of: ${hostName}";
                          deps = [ "check-vars" ];
                          cmds = [
                            ''echo "Rebuilding: {{.HOSTNAME}}"''
                            # For dry-running use `nixos-rebuild dry-activate`
                            (
                              if hostConfig.config.lollypops.deployment.local-evaluation then
                                ''
                                  nixos-rebuild {{.REBUILD_ACTION}} --flake '{{.REMOTE_CONFIG_DIR}}#{{.HOSTNAME}}' \
                                    --target-host {{.REMOTE_USER}}@{{.REMOTE_HOST}} \
                                    --build-host root@{{.REMOTE_HOST}}
                                ''
                              else
                                ''
                                  ssh {{.REMOTE_USER}}@{{.REMOTE_HOST}} "nixos-rebuild {{.REBUILD_ACTION}} --flake '{{.REMOTE_CONFIG_DIR}}#{{.HOSTNAME}}'"
                                ''
                            )
                          ];
                        };

                        deploy-flake = {

                          deps = [ "check-vars" ];
                          desc = "Deploy flake repository to: ${hostName}";
                          cmds = [
                            ''echo "Deploying flake to: {{.HOSTNAME}}"''
                            ''
                              source_path={{.LOCAL_FLAKE_SOURCE}}
                              if test -d "$source_path"; then
                                source_path=$source_path/
                              fi
                              ${pkgs.rsync}/bin/rsync \
                              --checksum \
                              --verbose \
                              -e ssh\ -l\ {{.REMOTE_USER}}\ -T \
                              -FD \
                              --times \
                              --perms \
                              --recursive \
                              --links \
                              --delete-excluded \
                              $source_path {{.REMOTE_USER}}\@{{.REMOTE_HOST}}:{{.REMOTE_CONFIG_DIR}}
                            ''
                          ];
                        };
                      };
                    });

                  # Taskfile passed to go-task
                  taskfile = pkgs.writeText
                    "Taskfile.yml"
                    (builtins.toJSON {
                      version = "3";
                      output = "prefixed";

                      # Don't print excuted commands. Can be overridden by -v
                      silent = true;

                      # Import the taks once for each host, setting the HOST
                      # variable. This allows running them as `host:task` for
                      # each host individually.
                      includes = builtins.mapAttrs
                        (name: value:
                          {
                            taskfile = mkTaskFileForHost name value;
                          })
                        configFlake.nixosConfigurations;

                      # Define grouped tasks to run all tasks for one host.
                      # E.g. to make a complete deployment for host "server01":
                      # `nix run '.' -- server01
                      tasks = builtins.mapAttrs
                        (name: value:
                          {
                            desc = "Provision host: ${name}";
                            cmds = [
                              # TODO make these configurable, set these three as default in the module
                              { task = "${name}:deploy-flake"; }
                              { task = "${name}:deploy-secrets"; }
                              { task = "${name}:rebuild"; }
                            ];
                          })
                        configFlake.nixosConfigurations // {
                        # Add special task called "all" which has all hosts as
                        # dependency to deploy all hosts at onece
                        all.deps = map (x: { task = x; }) (builtins.attrNames configFlake.nixosConfigurations);
                      };
                    });
                in
                flake-utils.lib.mkApp
                  {
                    drv = pkgs.writeShellScriptBin "go-task-runner" ''
                      ${pkgs.go-task}/bin/task -t ${taskfile} "$@"
                    '';
                  };
            };

        });
}
