{
  flake,
  pkgs,
  pname,
  ...
}:
let
  inherit (pkgs) lib;
in
pkgs.testers.runNixOSTest {
  name = pname;

  defaults.imports = [ flake.nixosModules.default ];

  nodes = {
    controller = {
      imports = [ flake.modules.test-nixos.ssh-client ];
    };
    target01 = {
      imports = [ flake.modules.test-nixos.ssh-server ];
      services.openssh.enable = true;
      lollypops.deployment.ssh.opts = [
        "-i/etc/ssh/keys/$USER"
      ];
    };
  };

  testScript =
    { nodes }:
    ''
      start_all()

      target01.wait_for_unit("sshd.service")
      controller.wait_for_unit("multi-user.target")

      for user in ("alice", "bob", "root"):
        code, output = controller.execute(
          fr"""
          sudo -nu {user} -- ${lib.getExe nodes.target01.lollypops.deployment.ssh.login} whoami
          """,
          timeout=2,
        )
        t.assertEqual(output.strip(), user)
    '';
}
