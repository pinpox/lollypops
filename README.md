# lollypops

Lollypop Operations - NixOS Deployment Tool

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
```

