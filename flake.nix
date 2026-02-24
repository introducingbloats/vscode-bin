{
  outputs =
    {
      self,
      ...
    }@inputs:
    let
      lib-nixpkgs = inputs.introducingbloats.lib.nixpkgs inputs;
    in
    {
      packages = lib-nixpkgs.forSystems lib-nixpkgs.linuxOnly (
        { pkgs, ... }:
        let
          mkVscode = channel: pkgs.callPackage ./package.nix { inherit channel; };
          stable = mkVscode "stable";
          insider = mkVscode "insider";
        in
        {
          default = stable;
          vscode-bin-stable = stable;
          vscode-bin-insider = insider;
          updateScript = pkgs.callPackage ./update.nix { };
        }
      );
    };
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11-small";
    introducingbloats.url = "github:introducingbloats/core.flakes/main";
  };
}
