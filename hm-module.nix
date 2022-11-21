{ config, lib, pkgs, ... }:

with lib;

let
  serviceConfig = config.services.lollypops-hm-test;
in
{
  # meta.maintainers = [ maintainers.DamienCassou ];

  options = {
    services.lollypops-hm-test = {
      enable = mkEnableOption "lollypops-hm-test service";
    };
  };

  config = mkIf serviceConfig.enable { };
}
