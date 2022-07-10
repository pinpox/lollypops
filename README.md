# lollypops

<p align="center">
  <img src="https://user-images.githubusercontent.com/1719781/176185996-f7bd3919-df7f-4684-b464-46b414b46483.png" height="200"/>  
</p>
<p align="center">
  Lollypop Operations - NixOS Deployment Tool
</p>

<p align="center">
  <a href="https://github.com/pinpox/lollypops/actions/workflows/nix.yml"><img src="https://github.com/pinpox/lollypops/actions/workflows/nix.yml/badge.svg" alt="Contributors badge" /></a>
</p>

Lollypops is a NixOS deployment tool build as a thin, pure nix wrapper around
[go-task](https://taskfile.dev/). It provides parallel deployment, secret
provisioning from any external source and configuration in nix itself among other
other features.

The deployment options and secrets are specified in each host's `flake.nix`
configuration. Lollypops then takes all `nixosConfigurations` and generates a
[go-task](https://taskfile.dev/) yaml configuration internally on the fly when
executed. This allows to run any selection of tasks in parallel or manually
execute a single step and take full advantage of all go-task
[features](https://taskfile.dev/usage/) while being fully customizable and
easily debuggable.

Lollypops is inspired by [krops](https://github.com/krebs/krops) and [colmena](https://github.com/zhaofengli/colmena).

## Features

- Stateless
- Parallel execution
- Configured in nix
- Easily extensible and customizable
- Minimal overhead and easy debugging
- Secret provisioning from any source (e.g. [pass](https://www.passwordstore.org/),
  [bitwarden](https://bitwarden.com/), plaintext files...)
- Fully flake compatible

## Usage

After configuration (see below) you will be able to run lollypops passing it one
or more arguments to specify which tasks to run. To see what tasks are available
use `--list-all`. Arguments are passed verbantim to go-task, use `--help` to get
a full list of options including output customizaion and debugging capabilities
or consult it's [documentation](https://taskfile.dev/usage/)

```sh
# List all Tasks
nix run '.' -- --list-all
* ahorn:
* ahorn:check-vars:
* ahorn:deploy-flake:
* ahorn:deploy-secrets:
* ahorn:rebuild:
* birne:
* birne:check-vars:
* birne:deploy-flake:
* birne:deploy-secrets:
* birne:rebuild:
```

Tasks are organized hierarchically by `hostname:tasks`. The above shows two
hosts `ahorn` and `birne` with their corresponding tasks. To provision a host
completely (run all tasks for this host) run:

```sh
# Run all tasks for a host
nix run '.' -- ahorn
```

This would run the tasks `ahorn:check-vars` `ahorn:deploy-flake`
`ahorn:deploy-secrets` and `ahorn:rebuild`. You can also only run a specific
subtask e.g.:

```sh
# Run specific task for a host
nix run '.' -- ahorn:deploy-secrets
```

This can be useful to quickly (re-)deploy a single secret or just run the
rebuilding step without setting the complete deployment in motion.

Lastly you can run multiple tasks in parallel by using the `--parallel flag`
(alias `-p`) and specifying multiple tasks. Keep in mind that dependencies are
run in parallel per default in go-task.

```sh
# Provision ahorn and birne in parallel
nix run '.' -- -p ahorn birne

[birne:deploy-flake] Deploying flake to: kartoffel
[ahorn:deploy-flake] Deploying flake to: ahorn
[ahorn:deploy-flake] sending incremental file list
[ahorn:deploy-flake] sent 7.001 bytes  received 125 bytes  14.252,00 bytes/sec
[ahorn:deploy-flake] total size is 667.681  speedup is 93,70
[ahorn:deploy-secrets] Deploying secrets to: ahorn
[ahorn:rebuild] Rebuilding: ahorn
[birne:deploy-flake] sent 9.092 bytes  received 205 bytes  15.252,00 bytes/sec
ssh: Could not resolve hostname kartoffel: Name or service not known
[ahorn:rebuild] building the system configuration...
...
```

### Override nixos-rebuild action

By default the rebuild step will run `nixos-rebuild switch` to activate the
configuration as part of the deployment. It is possible to override the default
(`switch`) rebuild action for testing, e.g. to set it to `boot`, `test` or
`dry-activate` by setting the environment variable `REBUILD_ACTION` to the
desired action, e.g.

```sh
REBUILD_ACTION=dry-activate nix run '.' -- -p ahorn birne
```

## Configuration

Add lollypops to your flake's inputs as you would for any dependency and import
the `lollypops` module in all hosts configured in your `nixosConfigurations`.

Then, use the the `apps` attribute set to expose the lollypops commands.
Here a single parameter is requied: `configFlake`. This is the flake containing
your `nixosConfigurations` from which lollypops will build it's task
specifications. In most cases this will be `self` because the app configuration
and the `nixosConfigurations` are defined in the same flake.

A complete minimal example:

```nix
{
  inputs = {
    lollypops.url = "github:pinpox/lollypops";
    # Other inputs ...
  };

  outputs = { nixpkgs, lollypops, self, ... }: {

    nixosConfigurations = {

      host1 = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          lollypops.nixosModules.lollypops
          ./configuration1.nix
        ];
      };

      host2 = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          lollypops.nixosModules.lollypops
          ./configuration2.nix
        ];
      };
    };

    apps."x86_64-linux".default = lollypops.apps."x86_64-linux".default { configFlake = self; };
  };
}
```

With this you are ready to start using lollypops. The above already should allow
you to list the tasks for two hosts with `--list-all`

```sh
nix run '.' --show-trace -- --list-all
task: Available tasks for this project:
* host1:
* host1:check-vars:
* host1:deploy-flake:
* host1:deploy-secrets:
* host1:rebuild:
* host2:
* host2:check-vars:
* host2:deploy-flake:
* host2:deploy-secrets:
* host2:rebuild:
```

To actually do something useful you can now use the options provided by the
lollypops module in your `configuration.nix` (or whereever your the
configuration of your host is specified).

The options exposed by the module are grouped into to groups:
`lollypops.deployment` for deployment options and `lollypops.secrets` to
configure... you guessed it, secrets.

### Deployment

Specify how and where to deploy. The default values may be sufficient here in
a lot of cases.

```nix
lollypops.deployment = {
  # Where on the remote the configuration (system flake) is placed
  config-dir = "/var/src/lollypops";

  # Ssh connection parameters
  host = "${config.networking.hostName}";
  user = "root";
};
```

Setting `lollypops.deployment.local-evaluation` to true, will result in
evaluation being done on the local side. This requires `nixos-rebuild` in your
`$PATH`

**Note:** Rsync is required on the remote for remote evaluation to work. While
the lollypops module will add the package to `environment.systemPackages` it may
be missing still on the first deployment. To fix this, either add it to your
$PATH on the remote side or do your first deployment with
`lollypops.deployment.local-evaluation` set to `true`.

### Secrets

Secrets are specified as attribute set under `lollypops.secrets.files`. All
parameters are optional and can be omitted except the name. In it's default
configuration `pass` will be used to search for the secret placing it in
`/run/keys/secretname` with permissions `0400` owned by `root:root`.

You can change the default secret directory using
`lollypops.secrets.default-dir` if you want to default to a different directory.

The `cmd` option expects a command that will print the secret value. This can be
any tool like a password manager that prints to stdout or a simple `cat
secretfile`. This allows integration with external sources of secrets. It will
be run on the local system to get the value to be placed in the remote file via
ssh.

```nix
  lollypops.secrets.files = {

    # Secret from a file with owner and group
    secret1 = {
      cmd = "pass test-password";
      path = "/var/lib/password-from-file";
      owner = "joe";
      groups = "mygroup";
    };

    # Secret from pass with default permissions
    "nixos-secrets/host1/backup-key" = {
      path = "/var/lib/backupconfig/password";
    };

    # Secret from bitwarden CLI
    secret2 = {
      cmd = "bw get password my-secret-token";
      path = "/home/pinpox/password-from-file";
      owner = "pinpox";
      groups = "pinpox";
    };
  };
```

See [module](https://github.com/pinpox/lollypops/blob/main/module.nix) for a
full list of options with defaults and example values.

### Debugging

lollypops hides the executed commands in the default output. To enable full
logging use the `--verbose` flag which is passed to go-task. 

### Contributing

Pull requests are very welcome!

This software is under active development. If you find bugs, please open an
issue and let me know. Open to feature request, tips and constructive criticism.

Let me know if you run into problems

<a href="https://www.buymeacoffee.com/pinpox"><img src="https://img.buymeacoffee.com/button-api/?text=Buy me a coffee&emoji=😎&slug=pinpox&button_colour=82aaff&font_colour=000000&font_family=Inter&outline_colour=000000&coffee_colour=FFDD00"></a>
