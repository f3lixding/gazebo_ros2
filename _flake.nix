# made with nix flake init --template github:lopsided98/nix-ros-overlay
{
  inputs = {
    nix-ros-overlay.url = "github:lopsided98/nix-ros-overlay/master";
    nixpkgs.follows = "nix-ros-overlay/nixpkgs"; # IMPORTANT!!!
  };
  outputs =
    {
      self,
      nix-ros-overlay,
      nixpkgs,
    }:
    nix-ros-overlay.inputs.flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ nix-ros-overlay.overlays.default ];
        };
        ros = pkgs.rosPackages.jazzy;
        py = ros.python3Packages;
        patchedCatkinPkg = py."catkin-pkg".overrideAttrs (old: {
          propagatedBuildInputs = builtins.map (
            pkg: if (pkg.pname or pkg.name or "") == "setuptools" then py.setuptools_79 else pkg
          ) old.propagatedBuildInputs;
        });
        patchedColconRos = py."colcon-ros".overrideAttrs (old: {
          propagatedBuildInputs = builtins.map (
            pkg: if (pkg.pname or pkg.name or "") == "catkin-pkg" then patchedCatkinPkg else pkg
          ) old.propagatedBuildInputs;
        });
        colcon = pkgs.buildEnv {
          name = "colcon-jazzy";
          paths = [
            py.colcon
            py."colcon-bash"
            py."colcon-cmake"
            py."colcon-defaults"
            py."colcon-library-path"
            py."colcon-metadata"
            py."colcon-notification"
            py."colcon-output"
            py."colcon-package-information"
            py."colcon-package-selection"
            py."colcon-parallel-executor"
            py."colcon-python-setup-py"
            py."colcon-recursive-crawl"
            patchedColconRos
            py."colcon-test-result"
            py."colcon-zsh"
          ];
        };
      in
      {
        devShells.default = pkgs.mkShell {
          name = "Example project";
          packages = [
            colcon
            # ... other non-ROS packages
            (
              with ros;
              buildEnv {
                paths = [
                  ros-core
                  # ... other ROS packages
                ];
              }
            )
          ];
          shellHook = ''
            exec ${pkgs.zsh}/bin/zsh
          '';
        };
      }
    );
  nixConfig = {
    extra-substituters = [ "https://ros.cachix.org" ];
    extra-trusted-public-keys = [ "ros.cachix.org-1:dSyZxI8geDCJrwgvCOHDoAfOm5sV1wCPjBkKL+38Rvo=" ];
  };
}
