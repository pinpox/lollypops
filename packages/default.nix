# Allow custom packages to be run using `nix run`
{
  pkgs,
  perSystem,
  pname,
  flake,
  configFlake ? flake,
  ...
}:
let
  taskfile = perSystem.self.taskfile.override { inherit configFlake; };
in
pkgs.writeShellScriptBin pname ''
  ${pkgs.go-task}/bin/task -t ${taskfile} "$@"
''
