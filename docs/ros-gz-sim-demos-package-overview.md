# `ros_gz_sim_demos` Package Overview

This note is based on the installed Jazzy package at:

- [ros_gz_sim_demos](/nix/store/sssi2c11s5rcy0ynm6in5w86xwavqxlv-ros-jazzy-ros-gz-sim-demos-1.0.22-r1)

The package metadata is in:

- [package.xml](/nix/store/sssi2c11s5rcy0ynm6in5w86xwavqxlv-ros-jazzy-ros-gz-sim-demos-1.0.22-r1/share/ros_gz_sim_demos/package.xml)

The package description there is:

- "Demos using Gazebo Sim simulation with ROS."

## Top Level Layout

The installed package mainly lives under:

- [share/ros_gz_sim_demos](/nix/store/sssi2c11s5rcy0ynm6in5w86xwavqxlv-ros-jazzy-ros-gz-sim-demos-1.0.22-r1/share/ros_gz_sim_demos)

Important subdirectories:

- `launch/`
- `models/`
- `rviz/`
- `worlds/`
- `environment/`
- `cmake/`

There is also:

- `share/ament_index/`
- `nix-support/`

## `launch/`

Path:

- [launch](/nix/store/sssi2c11s5rcy0ynm6in5w86xwavqxlv-ros-jazzy-ros-gz-sim-demos-1.0.22-r1/share/ros_gz_sim_demos/launch)

Purpose:

- contains ROS 2 launch files for each demo
- each file starts some combination of Gazebo, bridges, publishers, and RViz

Examples:

- `sdf_parser.launch.py`
  - loads the vehicle demo
  - starts Gazebo
  - starts `ros_gz_bridge`
  - starts `robot_state_publisher`
  - optionally starts RViz
- `diff_drive.launch.py`
  - demonstrates a differential-drive robot workflow
- `camera.launch.py`, `depth_camera.launch.py`, `rgbd_camera.launch.py`
  - sensor demos
- `gpu_lidar.launch.py`
  - lidar demo
- `tf_bridge.launch.py`
  - focused TF bridging demo

This folder is the main entry point when you run commands like:

```sh
ros2 launch ros_gz_sim_demos sdf_parser.launch.py rviz:=True
```

## `models/`

Path:

- [models](/nix/store/sssi2c11s5rcy0ynm6in5w86xwavqxlv-ros-jazzy-ros-gz-sim-demos-1.0.22-r1/share/ros_gz_sim_demos/models)

Purpose:

- stores demo robot and object descriptions used by the launch files and worlds

Examples:

- `vehicle/`
  - contains the simple vehicle used by `sdf_parser`
  - includes `model.sdf` and `model.config`
- `cardboard_box/`
  - a more complete Gazebo model directory
  - includes meshes, materials, and thumbnails
- `rrbot.xacro`
  - a Xacro robot description example
- `double_pendulum_model.sdf`
  - a standalone SDF model example

This is the content Gazebo resolves when a world references something like:

```xml
package://ros_gz_sim_demos/models/vehicle
```

## `worlds/`

Path:

- [worlds](/nix/store/sssi2c11s5rcy0ynm6in5w86xwavqxlv-ros-jazzy-ros-gz-sim-demos-1.0.22-r1/share/ros_gz_sim_demos/worlds)

Purpose:

- stores the demo Gazebo world files
- these worlds usually include models and plugins, then the launch files pass them into Gazebo

Examples:

- `vehicle.sdf`
  - the world used by the `sdf_parser` demo
- `dvl.sdf`
  - a world for the DVL demo
- `default.sdf`
  - a simple generic demo world

## `rviz/`

Path:

- [rviz](/nix/store/sssi2c11s5rcy0ynm6in5w86xwavqxlv-ros-jazzy-ros-gz-sim-demos-1.0.22-r1/share/ros_gz_sim_demos/rviz)

Purpose:

- stores preconfigured RViz layouts for the demos
- each file controls what RViz displays when the corresponding launch file starts RViz

Examples:

- `vehicle.rviz`
  - layout used by the `sdf_parser` vehicle demo
- `camera.rviz`
  - camera visualization setup
- `gpu_lidar.rviz`
  - lidar visualization setup
- `joint_states.rviz`
  - joint-state demo layout

These files are why the RViz window opens with a ready-made display panel instead of an empty default layout.

## `environment/`

Path:

- [environment](/nix/store/sssi2c11s5rcy0ynm6in5w86xwavqxlv-ros-jazzy-ros-gz-sim-demos-1.0.22-r1/share/ros_gz_sim_demos/environment)

Purpose:

- contains environment hooks that are meant to modify the shell environment when the package is sourced

In this package, the important job is adding the package's `share` directory to Gazebo resource lookup paths, so `package://ros_gz_sim_demos/...` URIs can be resolved.

That is the reason this package mattered for:

- `GZ_SIM_RESOURCE_PATH`

## `cmake/`

Path:

- [cmake](/nix/store/sssi2c11s5rcy0ynm6in5w86xwavqxlv-ros-jazzy-ros-gz-sim-demos-1.0.22-r1/share/ros_gz_sim_demos/cmake)

Purpose:

- contains package configuration files generated during installation
- mainly used by CMake / ament tooling so other packages can find this package

This folder matters more for build tooling than for day-to-day demo usage.

## `share/ament_index/`

Purpose:

- registers the package with the ROS ament index
- this is part of how commands like `ros2 pkg prefix ros_gz_sim_demos` can find it

## `local_setup.*` and `package.dsv`

Files:

- `local_setup.bash`
- `local_setup.sh`
- `local_setup.zsh`
- `local_setup.dsv`
- `package.dsv`

Purpose:

- shell integration files used when sourcing the package or a workspace
- they help export environment changes and package hooks

## `nix-support/`

Purpose:

- Nix-specific metadata for the built package
- not part of normal upstream ROS package structure

## Practical Summary

If you only care about how to use the package:

- `launch/` is where you start
- `models/` and `worlds/` are the Gazebo assets
- `rviz/` contains the RViz layouts
- `environment/` is what makes Gazebo resource lookup work when the environment is set up correctly
