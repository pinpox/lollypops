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
  [bitwarden](https://bitwarden.com/), plaintext files...)
- Fully flake compatible

## Usage
## WORK IN PROGRESS

Not usable yet. Development ongoing. It may change and any time. It may destroy
your system or burn everything to the ground.

(PR's welcome)


(did you read the above?)

```
# List all Tasks
nix run '.' -- --list-all

# Run specific task for a host
nix run '.' -- ahorn:deploy-secrets

# Run all tasks for a host
nix run '.' -- provision-ahorn
```

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

