# ROS, Gazebo, RViz, and This Nix Shell

This note distills the main things that mattered for getting ROS 2 Jazzy, Gazebo, and the `ros_gz` demos working in this repo.

Reference tutorial:

- https://gazebosim.org/docs/ionic/ros2_integration/

## Core Mental Model

- ROS 2 is usually the "brain" side:
  - nodes
  - topics
  - TF
  - launch files
  - robot logic
- Gazebo is the simulation side:
  - world
  - physics
  - sensors
  - robot dynamics
- `ros_gz_bridge` connects ROS 2 topics to Gazebo topics.
- `ros_gz_sim` provides ROS-friendly ways to launch and manage Gazebo.
- `ros_gz_sim_demos` is a package of example launches that show the integration in practice.

## What RViz Is

`rviz` / `rviz2` is ROS's visualization application.

It is not the simulator.

It shows ROS-side data such as:

- TF frames
- robot models from `robot_description`
- odometry
- sensor data
- markers, paths, maps, point clouds, scans

In the `sdf_parser` demo:

- Gazebo shows the simulated vehicle directly from the SDF world.
- RViz shows the ROS-side representation of that robot.

So it is normal to have:

- one Gazebo window
- one RViz window

## Why The `sdf_parser` Demo Was Confusing

The demo launch:

```sh
ros2 launch ros_gz_sim_demos sdf_parser.launch.py rviz:=True
```

starts:

- Gazebo
- `ros_gz_bridge`
- `robot_state_publisher`
- RViz

Two details mattered on this machine.

### 1. The demo world starts paused

The launch file passes only the world path into `gz_sim.launch.py`. It does not pass `-r`, so Gazebo starts paused.

That matters because before unpausing:

- `/joint_states` may exist
- the Gazebo window can still show the vehicle
- but dynamic data such as odometry / TF may not be available yet

When the world was unpaused, `/model/vehicle/odometry` started publishing with:

- `frame_id: vehicle/odom`
- `child_frame_id: vehicle`

So if RViz complains about missing transforms right after launch, one likely reason is simply that the simulation has not started running yet.

### 2. GUI and Gazebo transport needed explicit environment setup

On this machine, the shell needed:

- graphical session variables
- `GZ_IP=127.0.0.1`
- `GZ_PARTITION=gazebo$UID`
- `QT_QPA_PLATFORM=xcb`
- `GZ_SIM_RESOURCE_PATH` including the `ros_gz_sim_demos` share directory

Those are set in [flake.nix](/home/felix/doodle/gazebo_sso2/flake.nix).

## What The Nix Flake Is Doing

The important structure in [flake.nix](/home/felix/doodle/gazebo_sso2/flake.nix) is:

```nix
ros = pkgs.rosPackages.jazzy.overrideScope (...);
```

That means:

- start from the Jazzy ROS package set provided by `nix-ros-overlay`
- optionally override a few packages

Then:

```nix
rosEnv = with ros; buildEnv {
  paths = [
    ros-core
    simulation-interfaces
    ros-gz-bridge
    ros-gz-interfaces
    ros-gz-sim
    ros-gz-sim-demos
    sdformat-urdf
    rviz2
  ];
};
```

This means:

- take those ROS packages from the Jazzy package set
- combine them into one environment
- expose that combined environment inside the dev shell

`buildEnv` does not decide what ROS packages exist. It only bundles packages that already exist in the `ros` package set.

## How `buildEnv` Knows Where To Download Packages

Short answer: it does not.

`buildEnv` only combines package outputs. The download/build information comes from the package definitions in the ROS package set.

The chain is:

1. `nix-ros-overlay` defines `pkgs.rosPackages.jazzy`
2. that package set contains derivations like `ros-gz-sim`, `rviz2`, `sdformat-urdf`, etc.
3. each derivation already knows its own source URL, revision, hash, build steps, and dependencies
4. `buildEnv` just bundles the resulting packages into one environment

So:

- `paths = [ ros-gz-sim rviz2 ... ]` means "include these already-defined packages"
- it does not mean "`buildEnv` should go figure out where `ros-gz-sim` lives on the internet"

For ROS packages in `nix-ros-overlay`, the source definitions usually come from generated package expressions under the overlay's distro package set. Vendor packages may fetch extra upstream sources on top of that.

## How A ROS Package Gets Into The Ecosystem

ROS does not have a single npm-style registry service.

Instead, the release/index flow is split across a few parts:

- `package.xml`
- `rosdistro`
- `bloom`
- the ROS build farm
- ROS Index

The rough flow for a package owner is:

1. Put the package in a public repository with a valid `package.xml`.
2. Make sure the repository is indexed in `rosdistro`.
3. Create a release repository.
4. Run `bloom-release --rosdistro jazzy <repo_name>`.
5. `bloom` opens a pull request against `ros/rosdistro`.
6. After that PR is merged and built, the package becomes part of that ROS distribution.

So the closest thing to a central registry is `rosdistro`, but it is not exactly like npm.

The comparison is:

- `package.xml` is the closest thing to `package.json`
- `bloom` is the release tool
- `rosdistro` is the released-package index
- ROS Index is the searchable package catalog
- `packages.ros.org` is the binary package distribution endpoint for supported platforms

For this Nix setup, `nix-ros-overlay` is downstream of that process. It consumes ROS distro metadata and turns it into Nix package definitions. A ROS package owner normally releases into ROS first, not directly into Nix.

## Why `ros_gz_sim_demos` Worked Only After Extra Shell Setup

The demo package installs models and worlds under its own `share/` directory.

Gazebo needed that path in `GZ_SIM_RESOURCE_PATH` in order to resolve:

```xml
package://ros_gz_sim_demos/models/vehicle
```

That is why the shell exports:

```sh
export GZ_SIM_RESOURCE_PATH="${ros.ros-gz-sim-demos}/share..."
```

Without that, Gazebo could launch but fail to find the demo model resources.

## Practical Summary

- Gazebo is the simulator.
- RViz is the ROS visualization tool.
- `ros_gz_bridge` bridges ROS and Gazebo topics.
- `ros_gz_sim` launches Gazebo from ROS 2.
- `ros_gz_sim_demos` provides example launch files.
- `buildEnv` bundles ROS packages into one shell environment; it does not discover package download URLs.
- The `sdf_parser` demo can show RViz TF warnings before the sim is unpaused.
- On this machine, GUI and Gazebo transport also needed explicit environment variables.
