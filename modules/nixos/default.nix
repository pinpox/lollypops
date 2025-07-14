{ flake, ... }:
{
  key = "github:pinpox/lollypops#modules.nixos.default";

  imports = [
    flake.modules.common.secrets
    flake.modules.nixos.deployment
    flake.modules.nixos.tasks
  ];
}
