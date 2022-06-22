{
  description = "A very basic flake";

  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  };

  outputs = { self, ... }@inputs:
    with inputs;
    {
      nixosModules.lollypops = import ./module.nix;
      nixosModule = self.nixosModules.lollypops;
    } //

    # All packages in the ./packages subfolder are also added to the flake.
    # flake-utils is used for this part to make each package available for each
    # system. This works as all packages are compatible with all architectures
    (flake-utils.lib.eachSystem [ "aarch64-linux" "i686-linux" "x86_64-linux" ])
      (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        rec {
          # Allow custom packages to be run using `nix run`
          apps =
            let
              mkSeclist = config: pkgs.lib.lists.flatten (map
                (x: [
                  "echo 'Deploying ${x.name} to ${x.path}'"
                  # Remove if already
                  ''
                    ssh ${config.lollypops.deployment.user}@${config.lollypops.deployment.host} "rm -f ${x.path}"
                  ''
                  # Copy file
                  ''
                    ${x.cmd} | ssh ${config.lollypops.deployment.user}@${config.lollypops.deployment.host} "umask 077; cat > ${x.path}"
                  ''
                  # Set group and owner
                  ''
                    ssh ${config.lollypops.deployment.user}@${config.lollypops.deployment.host} "chown ${x.owner}:${x.group-name} ${x.path}"
                  ''
                ])
                (builtins.attrValues config.lollypops.secrets.files));

            in
            {

              default = { nixosConfigurations, ... }:
                let

                  mkTaskFileForHost = hostConfig: pkgs.writeText "CommonTasks.yml"
                    (builtins.toJSON {
                      version = "3";

                      tasks = {

                        greet.cmds = [ ''echo "Hello {{.HOST}}"'' ];

                        check-vars.preconditions = [{
                          sh = ''[ ! -z "{{.HOST}}" ]'';
                          msg = "HOST not set: {{.HOST}}";
                        }];

                        deploy-secrets = {
                          deps = [ "check-vars" ];

                          # silent = true;

                          cmds = [
                            ''echo "Deploying secrets to: {{.HOST}} (not impletmented yet)!"''
                          ] ++ mkSeclist hostConfig.config;

                        };

                        rebuild = {
                          dir = self;
                          deps = [ "check-vars" ];
                          cmds = [
                            # TODO commented out for testing
                            ''
                              echo "Rebuilding: {{.HOST}}!"
                              # nixos-rebuild switch --flake '.#{{.HOST}}' --target-host root@{{.HOST}} --build-host root@{{.HOST}}
                            ''
                          ];
                        };

                        deploy-flake = {
                          deps = [ "check-vars" ];
                          cmds = [
                            ''echo "Deploying flake to: {{.HOST}} (not impletmented yet)!"''
                          ];
                        };
                      };
                    });

                  # Taskfile passed to go-task
                  taskfile = pkgs.writeText
                    "Taskfile.yml"
                    (builtins.toJSON {
                      version = "3";
                      # Import the takes once for each host, setting the HOST
                      # variable. This allows running them as `host:task` for
                      # each host individually. Available hostnames are take form
                      # the ./machines directory

                      includes = builtins.mapAttrs
                        (name: value:
                          {
                            taskfile = mkTaskFileForHost value;
                            vars.HOST = name;
                          })
                        nixosConfigurations;

                      # Define grouped tasks to run all tasks for one host.
                      # E.g. to make a complete deployment for host "server01":
                      # `nix run '.' -- server01
                      tasks = builtins.mapAttrs
                        (name: value:
                          {
                            cmds = [
                              # TODO make these configurable
                              # { task = "ahorn:greet"; }
                              { task = "${name}:deploy-flake"; }
                              {
                                task = "${name}:deploy-secrets";
                              }
                              { task = "${name}:rebuild"; }
                            ];
                          })
                        nixosConfigurations;
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
