# lollypops

<p align="center">
  <img src="https://user-images.githubusercontent.com/1719781/176174434-9813865f-9b1d-4a8f-aa45-7c2f30023ae2.svg" height="200"/>  
</p>
<p align="center">
  Lollypop Operations - NixOS Deployment Tool
</p>

<p align="center">
  <a href="https://github.com/pinpox/lollypops/actions/workflows/nix.yml"><img src="https://github.com/pinpox/lollypops/actions/workflows/nix.yml/badge.svg" alt="Contributors badge" /></a>
</p>

Lollypops is a NixOs deployment tool build as a thin, pure nix wrapper around
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

Lollypops is inspired by [krops](https://github.com/krebs/krops)
[colmena](https://github.com/zhaofengli/colmena).

# Features

- Stateless
- Parallel execution
- Configured in nix
- Easily extensible and customizable
- Minimal overhead and easy debugging
- Secret provisioning from any source (e.g. [pass](https://www.passwordstore.org/),
  [bitwarden](https://bitwarden.com/), plaintext files)
- Fully flake compatible

## Usage
## WORK IN PROGRESS

Not usable yet. Development ongoing. It may change and any time. It may destroy
your system or burn everything to the ground.

(PR's welcome)


(did you read the above?)

After configuration (see below) you will be able to run lollypops passing it one
or more arguments to specify which tasks to run. To see what tasks are avaiable
use `--list-all`. Arguments are passed verbantim to go-task, use `--help` to get
a full list of options including output customizaion and debugging capabilities
or consult it's [documentation](https://taskfile.dev/usage/)

```
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

```
# Run all tasks for a host
nix run '.' -- ahorn
```

This would run the tasks `ahorn:check-vars` `ahorn:deploy-flake`
`ahorn:deploy-secrets` and `ahorn:rebuild`. You can also only run a specific
subtask e.g.:

```
# Run specific task for a host
nix run '.' -- ahorn:deploy-secrets
```

This can be useful to quickly (re-)deploy a single secret or just run the
rebuilding step without setting the complete deployment in motion.

Lastly you can run multiple tasks in parallel by using the `--parallel flag`
(alias `-p`) and specifying multiple tasks. Keep in mind that dependencies are
run in parallel per default in go-task.

```
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

### Configuration

### Secrets

## Debuggging
--verbose


# Other

```nix
# flake.nix
# TODO flake input and module import

apps = {
		default = lollypops.apps."${system}".default { configFlake = self; };
};
```

Define your secrets in your host's `configuration.nix`. See `module.nix` for all
possible options.

```nix
# configuration.nix

lollypops.secrets.files = {
	secret1 = {
		cmd = "pass test-password";
		path = "/tmp/secretfile";
	};
};


  lollypops.secrets.files = {
    secret1 = {
      cmd = "pass test-password";
      path = "/tmp/testfile5";
    };

    "nixos-secrets/ahorn/ssh/borg/public" = {
      path = "/tmp/testfile7";
    };
  };
```

