{ flake, ... }:
{
  key = "github:pinpox/lollypops#modules.home.default";

  imports = [
    flake.modules.common.secrets
  ];
}
