{
  inputs = {
    nix-ros-overlay.url = "github:lopsided98/nix-ros-overlay/master";
    nixpkgs.follows = "nix-ros-overlay/nixpkgs";
  };

  outputs =
    {
      nix-ros-overlay,
      nixpkgs,
      ...
    }:
    nix-ros-overlay.inputs.flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [
            (final: prev: {
              tbb_2022 = prev.tbb_2022_0;
            })
            nix-ros-overlay.overlays.default
          ];
        };
        ros = pkgs.rosPackages.jazzy.overrideScope (
          rosFinal: rosPrev: {
            # nix-ros-overlay currently has stale fetchpatch hashes for Ogre.
            gz-ogre-next-vendor =
              (rosFinal.lib.patchAmentVendorGit rosPrev.gz-ogre-next-vendor {
                patchesFor.gz_ogre_next_vendor = [
                  (pkgs.fetchpatch2 {
                    url = "https://github.com/OGRECave/ogre-next/commit/98c9095c6e288fceb59ccb3504d9127d88eb1b51.patch";
                    hash = "sha256-m1CkqcD2e0WW6zIEVOCmTQk7Fm1r7J67pekZJSc+aiA=";
                  })
                  (pkgs.fetchpatch2 {
                    url = "https://github.com/OGRECave/ogre-next/commit/37d4876eb71c70b9eb3464e5b72c6e6d6be03232.patch";
                    hash = "sha256-vrVv2PWbyDqM6+fhyg3N5QhUzwvJrmGdTzULfvLSyUY=";
                  })
                  (pkgs.fetchpatch2 {
                    url = "https://github.com/OGRECave/ogre-next/commit/96a3bb016b2c9b4f9cca9df1a65d619220e21d78.patch";
                    hash = "sha256-ZHQNF1u5+OvdmN1E7uHxeeWO9x8gzbOrIj/VAJVw9Ps=";
                  })
                ];
              }).overrideAttrs
                (
                  {
                    postPatch ? "",
                    ...
                  }:
                  {
                    postPatch = postPatch + ''
                      substituteInPlace CMakeLists.txt \
                        --replace-fail 'CMAKE_ARGS' 'CMAKE_ARGS -DOGRE_CONFIG_ENABLE_STBI:BOOL=ON'
                    '';
                    dontFixCmake = true;
                  }
                );
          }
        );
        rosEnv =
          with ros;
          buildEnv {
            paths = [
              ros-core
              simulation-interfaces
              ros-gz-interfaces
              ros-gz-sim
            ];
          };
      in
      {
        devShells.default = pkgs.mkShell {
          name = "ros-gz-jazzy";
          packages = [ rosEnv ];
          shellHook = ''
            if [[ $- == *i* ]]; then
              exec ${pkgs.zsh}/bin/zsh
            fi
          '';
        };
      }
    );

  nixConfig = {
    extra-substituters = [ "https://ros.cachix.org" ];
    extra-trusted-public-keys = [ "ros.cachix.org-1:dSyZxI8geDCJrwgvCOHDoAfOm5sV1wCPjBkKL+38Rvo=" ];
  };
}
