{
  description = "Lollypops - Lollypop Operations Deployment Tool";

  inputs = {
    blueprint.url = "github:numtide/blueprint/refs/pull/122/head"; # HACK
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  };

  outputs = inputs: inputs.blueprint { inherit inputs; };
}
