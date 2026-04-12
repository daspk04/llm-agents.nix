{
  pkgs,
  perSystem,
  ...
}:
pkgs.callPackage ../openfang/desktop.nix {
  inherit (perSystem.self) claude-code;
}
