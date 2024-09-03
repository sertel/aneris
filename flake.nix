{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/release-24.05";
    flake-utils.url = "github:numtide/flake-utils";

    trillium.url="github:sertel/trillium";
    trillium.inputs.nixpkgs.follows="nixpkgs";

    actris.url="github:sertel/actris?ref=nix-support";
    actris.inputs.nixpkgs.follows="nixpkgs";

    coq-record-update.url="github:tchajed/coq-record-update";
    coq-record-update.inputs.nixpkgs.follows="nixpkgs";
  };
  outputs = { self, nixpkgs, flake-utils, trillium, actris, coq-record-update, ... }: let

    aneris = { lib, mkCoqDerivation, coq, stdpp, iris, paco }: mkCoqDerivation rec {
      pname = "aneris";
      propagatedBuildInputs = [ stdpp iris paco trillium coq-record-update actris ];
      defaultVersion = "0.0.1";
      release."0.0.1" = {
        src = lib.const (lib.cleanSourceWith {
          src = lib.cleanSource ./.;
          filter = let inherit (lib) hasSuffix; in path: type:
            (! hasSuffix ".gitignore" path)
            && (! hasSuffix "flake.nix" path)
            && (! hasSuffix "flake.lock" path)
            && (! hasSuffix "_build" path);
        });
      };
    };

  in flake-utils.lib.eachDefaultSystem (system: let
    pkgs = import nixpkgs {
      inherit system;
      overlays = [ self.overlays.default ];
    };
  in {
    devShells = {
      aneris = self.packages.${system}.aneris;
      default = self.packages.${system}.aneris;
    };

    packages = {
      aneris = pkgs.coqPackages_8_19.aneris;
      default = self.packages.${system}.aneris;
    };
  }) // {
    # NOTE: To use this flake, apply the following overlay to nixpkgs and use
    # the injected package from its respective coqPackages_VER attribute set!
    overlays.default = final: prev: let
      injectPkg = name: set:
        prev.${name}.overrideScope (self: _: {
          aneris = self.callPackage aneris {};
        });
    in (nixpkgs.lib.mapAttrs injectPkg {
      inherit (final) coqPackages_8_19;
    });
  };
}
