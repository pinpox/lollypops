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
        {

          packages = rec {
            default = docs;
            docs = pkgs.callPackage ./docs.nix {
              filterPrefix = "lollypops";
              title = "Lollypops options";
              modules = [
                (import ./module.nix {
                  inherit pkgs;
                  lib = pkgs.lib;
                  config.networking.hostName = "hostname";
                })
                {
                  # Fake this so depending options documentation don't fail
                  options.environment = pkgs.lib.mkOption { description = "test"; };
                }
              ];
            };
          };

          # Allow custom packages to be run using `nix run`
          apps =
            let

              # Build steps for all secrets of all users
              mkSeclistUser = homeUsers: pkgs.lib.lists.flatten (builtins.attrValues (builtins.mapAttrs
                (user: userconfig: [
                  # Deploy secrets for user 'user'
                  (builtins.attrValues (builtins.mapAttrs
                    (secretName: secretConfig: [
                      # Deloy secret 'secretName' of user 'user'
                      "echo 'Deploying ${secretName} (from user ${user}) to ${pkgs.lib.escapeShellArg secretConfig.path}'"

                      # Create parent directory if it does not exist
                      ''
                        {{.REMOTE_COMMAND}} {{.REMOTE_SSH_OPTS}} {{.REMOTE_USER}}@{{.REMOTE_HOST}} 'umask 076; sudo -u ${user} mkdir -p "$(dirname ${pkgs.lib.escapeShellArg secretConfig.path})"'
                      ''
                      # Copy file
                      ''
                        ${secretConfig.cmd} | {{.REMOTE_COMMAND}} {{.REMOTE_SSH_OPTS}} {{.REMOTE_USER}}@{{.REMOTE_HOST}} "umask 077; cat > ${pkgs.lib.escapeShellArg secretConfig.path}"
                      ''
                      # # Set group and owner
                      ''
                        {{.REMOTE_COMMAND}} {{.REMOTE_SSH_OPTS}} {{.REMOTE_USER}}@{{.REMOTE_HOST}} "chown ${secretConfig.owner}:${secretConfig.group-name} ${pkgs.lib.escapeShellArg secretConfig.path}"
                      ''
                    ])
                    userconfig.lollypops.secrets.files))

                ])
                homeUsers));



            in
            {

              default = { configFlake, ... }:
                let

                  mkTaskFileForHost = hostName: hostConfig: pkgs.writeText "CommonTasks.yml"
                    (builtins.toJSON {
                      version = "3";
                      output = "prefixed";
                      # Set global shell options:
                      # set -o pipefail -e
                      set = [
                        "e"
                        "pipefail"
                      ];

                      vars = with hostConfig.config.lollypops; {
                        REMOTE_USER = ''{{default "${deployment.ssh.user}" .LP_REMOTE_USER}}'';
                        REMOTE_HOST = ''{{default "${deployment.ssh.host}" .LP_REMOTE_HOST}}'';
                        REMOTE_COMMAND = ''{{default "${deployment.ssh.command}" .LP_REMOTE_COMMAND}}'';
                        REMOTE_SSH_OPTS = ''{{default "${pkgs.lib.concatStringsSep " " deployment.ssh.opts}" .LP_REMOTE_SSH_OPTS}}'';
                        REMOTE_SUDO_COMMAND = ''{{default "${deployment.sudo.command}" .LP_REMOTE_SUDO_COMMAND}}'';
                        REMOTE_SUDO_OPTS = ''{{default "${pkgs.lib.concatStringsSep " " deployment.sudo.opts}" .LP_REMOTE_SUDO_OPTS}}'';
                        REBUILD_ACTION = ''{{default "switch" .REBUILD_ACTION}}'';
                        REMOTE_CONFIG_DIR = deployment.config-dir;
                        LOCAL_FLAKE_SOURCE = configFlake;
                        HOSTNAME = hostName;
                      };

                      tasks =
                        let
                          useSudo = hostConfig.config.lollypops.deployment.sudo.enable;
                        in
                        with pkgs.lib; {

                          check-vars.preconditions = [{
                            sh = ''[ ! -z "{{.HOSTNAME}}" ]'';
                            msg = "HOSTNAME not set: {{.HOSTNAME}}";
                          }];

                          deploy-secrets =
                            let
                              mkSeclist = config: lists.flatten (map
                                (x:
                                  let
                                    path = escapeShellArg x.path;
                                  in
                                  [
                                    "echo 'Deploying ${x.name} to ${path}'"

                                    # Create parent directory if it does not exist
                                    ''
                                      {{.REMOTE_COMMAND}} {{.REMOTE_SSH_OPTS}} {{.REMOTE_USER}}@{{.REMOTE_HOST}} \
                                      'umask 076; ${optionalString useSudo "{{.REMOTE_SUDO_COMMAND}} {{.REMOTE_SUDO_OPTS}} "} mkdir -p "$(dirname ${path})"'
                                    ''

                                    # Copy file
                                    ''
                                      ${x.cmd} | {{.REMOTE_COMMAND}} {{.REMOTE_SSH_OPTS}} {{.REMOTE_USER}}@{{.REMOTE_HOST}} \
                                      "${optionalString useSudo "{{.REMOTE_SUDO_COMMAND}} {{.REMOTE_SUDO_OPTS}}"} \
                                      install -m 700 /dev/null ${path}; \
                                      ${optionalString useSudo "{{.REMOTE_SUDO_COMMAND}} {{.REMOTE_SUDO_OPTS}}"} \
                                      tee ${path} > /dev/null"
                                    ''

                                    # Set group and owner
                                    ''
                                      {{.REMOTE_COMMAND}} {{.REMOTE_SSH_OPTS}} {{.REMOTE_USER}}@{{.REMOTE_HOST}} \
                                      "${optionalString useSudo "{{.REMOTE_SUDO_COMMAND}} {{.REMOTE_SUDO_OPTS}}"} \
                                      chown ${x.owner}:${x.group-name} ${path}"
                                    ''
                                  ])
                                (builtins.attrValues config.lollypops.secrets.files));
                            in
                            {
                              deps = [ "check-vars" ];

                              desc = "Deploy secrets to: ${hostName}";

                              cmds = [
                                ''echo "Deploying secrets to: {{.HOSTNAME}}"''
                              ]
                              ++ mkSeclist hostConfig.config
                              ++ (
                                # Check for home-manager
                                if builtins.hasAttr "home-manager" hostConfig.config then
                                  (
                                    # Check for lollypops hmModule
                                    if builtins.hasAttr "lollypops" hostConfig.config.home-manager then
                                      mkSeclistUser hostConfig.config.home-manager.users else [ ]
                                  )
                                else [ ]
                              );
                            };

                          rebuild = {
                            dir = self;

                            desc = "Rebuild configuration of: ${hostName}";
                            deps = [ "check-vars" ];
                            cmds = [
                              (if hostConfig.config.lollypops.deployment.local-evaluation then
                                ''
                                  ${optionalString useSudo ''NIX_SSHOPTS="{{.REMOTE_SSH_OPTS}}"''} nixos-rebuild {{.REBUILD_ACTION}} \
                                    --flake '{{.LOCAL_FLAKE_SOURCE}}#{{.HOSTNAME}}' \
                                    --target-host {{.REMOTE_USER}}@{{.REMOTE_HOST}} \
                                    ${optionalString useSudo "--use-remote-sudo"}
                                '' else ''
                                {{.REMOTE_COMMAND}} {{.REMOTE_SSH_OPTS}} {{.REMOTE_USER}}@{{.REMOTE_HOST}} \
                                  '${optionalString useSudo "{{.REMOTE_SUDO_COMMAND}} {{.REMOTE_SUDO_OPTS}}"} nixos-rebuild {{.REBUILD_ACTION}} \
                                  --flake "$(readlink -f {{.REMOTE_CONFIG_DIR}}/flake)#{{.HOSTNAME}}"'
                              '')
                            ];
                          };

                          deploy-flake = {

                            deps = [ "check-vars" ];
                            desc = "Deploy flake repository to: ${hostName}";
                            cmds = [
                              ''echo "Deploying flake to: {{.HOSTNAME}}"''
                              (if  hostConfig.config.lollypops.deployment.deploy-method == "archive" then
                                ''
                                  NIX_SSHOPTS="{{.REMOTE_SSH_OPTS}}" nix flake archive \
                                    --to ssh://{{.REMOTE_USER}}@{{.REMOTE_HOST}} \
                                    --option builders-use-substitutes true \
                                    {{.LOCAL_FLAKE_SOURCE}}
                                ''
                              else
                                ''
                                  NIX_SSHOPTS="{{.REMOTE_SSH_OPTS}}" nix copy \
                                    --to ssh://{{.REMOTE_USER}}@{{.REMOTE_HOST}} \
                                    --substitute-on-destination \
                                    --option builders-use-substitutes true \
                                    {{.LOCAL_FLAKE_SOURCE}}
                                ''
                              )
                              ''
                                {{.REMOTE_COMMAND}} {{.REMOTE_SSH_OPTS}} {{.REMOTE_USER}}@{{.REMOTE_HOST}} \
                                  "${optionalString useSudo "{{.REMOTE_SUDO_COMMAND}} {{.REMOTE_SUDO_OPTS}}"} ln -sfn {{.LOCAL_FLAKE_SOURCE}} {{.REMOTE_CONFIG_DIR}}/flake"
                              ''
                            ];
                          };
                        } // hostConfig.config.lollypops.extraTasks;
                    });


                  # Group hosts by their group name
                  hostGroups =
                    let
                      processHost = currentGroups: host:
                        let
                          groupName = host.config.lollypops.deployment.group;
                          existing = currentGroups."${groupName}" or [ ];
                        in
                        # Either add the host to an existing group or create a new group list
                        currentGroups // { ${groupName} = existing ++ [ host.config.system.name ]; };
                    in
                    builtins.foldl' processHost { } (builtins.attrValues configFlake.nixosConfigurations);


                  # Taskfile passed to go-task
                  taskfile = pkgs.writeText
                    "Taskfile.yml"
                    (builtins.toJSON {
                      version = "3";
                      output = "prefixed";

                      # Don't print executed commands. Can be overridden by -v
                      silent = true;

                      # Import the tasks once for each host, setting the HOST
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
                            cmds = map (task: { task = "${name}:${task}"; }) value.config.lollypops.tasks;
                          })
                        configFlake.nixosConfigurations // builtins.mapAttrs
                        (groupName: hosts:
                          {
                            desc = "Provision group: ${groupName}";
                            deps = map (host: { task = "${host}"; }) hosts;
                          })
                        hostGroups // {
                        # Add special task called "all" which has all hosts as
                        # dependency to deploy all hosts at once
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
