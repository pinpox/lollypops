# lollypops
<p align="center">
  <img src="https://user-images.githubusercontent.com/1719781/176172739-1ee4447e-a758-432f-9a53-22c17f2d3319.svg" height="200"/>
</p>
<p align="center">
  Lollypop Operations - NixOS Deployment Tool
</p>



## WORK IN PROGRESS

Not usable yet. Development ongoing. It may change and any time. It may destroy
your system or burn everything to the ground.

(PR's welcome)

## Usage

(did you read the above?)

```
# List all Tasks
nix run '.' -- --list-all

# Run specific task for a host
nix run '.' -- ahorn:deploy-secrets

# Run all tasks for a host
nix run '.' -- provision-ahorn
```

# Parallel execution

TODO: document

## Debuggging
--verbose


# Features
- Stateless
- Parallel execution
- Secret provisioning from any source

# Other

```nix
# flake.nix
# TODO flake input and module import

apps = {
	default = lollypops.apps."${system}".default { nixosConfigurations = self.nixosConfigurations; };
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

