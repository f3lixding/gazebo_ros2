# `vehicle.sdf` Demo Flow

This note explains how the `ros_gz_sim_demos` vehicle example fits together.

It is meant to answer the common confusion points:

- what "model" means in Gazebo
- where topics like `/model/vehicle/cmd_vel` come from
- which file is responsible for what
- how the bridge and `ros2 topic pub` fit into the flow

## Core Terms

### World

A **world** is the top-level simulation scene.

It contains things like:

- lights
- ground plane
- physics
- one or more models

In this demo, the world file is:

- [vehicle.sdf](/nix/store/sssi2c11s5rcy0ynm6in5w86xwavqxlv-ros-jazzy-ros-gz-sim-demos-1.0.22-r1/share/ros_gz_sim_demos/worlds/vehicle.sdf)

### Model

A **model** in Gazebo means one simulated object or robot instance.

It is not just the 3D mesh.

A model can include:

- links
- joints
- inertial properties
- collisions
- visuals
- sensors
- plugins

In this demo, the vehicle model definition is:

- [model.sdf](/nix/store/sssi2c11s5rcy0ynm6in5w86xwavqxlv-ros-jazzy-ros-gz-sim-demos-1.0.22-r1/share/ros_gz_sim_demos/models/vehicle/model.sdf)

## What Each File Does

### 1. `worlds/vehicle.sdf`

Path:

- [vehicle.sdf](/nix/store/sssi2c11s5rcy0ynm6in5w86xwavqxlv-ros-jazzy-ros-gz-sim-demos-1.0.22-r1/share/ros_gz_sim_demos/worlds/vehicle.sdf)

Main job:

- defines the simulation world
- creates a model instance named `vehicle`
- attaches world/model-level publisher plugins

Important lines:

- it creates the model instance:

```xml
<model name="vehicle">
```

- it includes the actual robot definition:

```xml
<include merge="true">
  <uri>package://ros_gz_sim_demos/models/vehicle</uri>
</include>
```

- it adds these plugins to that model instance:
  - `JointStatePublisher`
  - `PosePublisher`
  - `OdometryPublisher`

So this file is where the simulation decides:

- there is a model named `vehicle`
- in a world named `demo`
- with pose / joint / odometry publishers enabled

### 2. `models/vehicle/model.sdf`

Path:

- [model.sdf](/nix/store/sssi2c11s5rcy0ynm6in5w86xwavqxlv-ros-jazzy-ros-gz-sim-demos-1.0.22-r1/share/ros_gz_sim_demos/models/vehicle/model.sdf)

Main job:

- defines the robot itself

It contains:

- links:
  - `chassis`
  - `left_wheel`
  - `right_wheel`
  - `caster`
- joints:
  - `left_wheel_joint`
  - `right_wheel_joint`
  - `caster_wheel`
- the `DiffDrive` plugin

The important runtime behavior comes from:

```xml
<plugin
  filename="ignition-gazebo-diff-drive-system"
  name="ignition::gazebo::systems::DiffDrive">
```

That plugin is what makes the robot move when it receives velocity commands.

### 3. Bridge YAML

Path:

- [ros_gz_bridge_sdf_parser.yaml](/home/felix/doodle/gazebo_sso2/config/ros_gz_bridge_sdf_parser.yaml)

Main job:

- tells the bridge which ROS topics and Gazebo topics to translate between

It does not know about SDF structure directly.

It only knows:

- topic names
- message types
- direction

Example:

```yaml
- ros_topic_name: "/model/vehicle/cmd_vel"
  gz_topic_name: "/model/vehicle/cmd_vel"
  ros_type_name: "geometry_msgs/msg/Twist"
  gz_type_name: "gz.msgs.Twist"
  direction: "BIDIRECTIONAL"
```

### 4. `ros2 topic pub`

Example:

```sh
ros2 topic pub /model/vehicle/cmd_vel geometry_msgs/msg/Twist \
  "{linear: {x: 0.5}, angular: {z: 0.2}}"
```

Main job:

- publishes a ROS message onto the ROS topic `/model/vehicle/cmd_vel`

It does not know anything about `vehicle.sdf`.

It only knows:

- topic name
- message type
- message payload

## Where `/model/vehicle/cmd_vel` Comes From

This is the key part.

You do not see `<cmd_vel>` written in `vehicle.sdf` because the topic is not declared there explicitly.

Instead, the topic comes from the `DiffDrive` plugin attached in [model.sdf](/nix/store/sssi2c11s5rcy0ynm6in5w86xwavqxlv-ros-jazzy-ros-gz-sim-demos-1.0.22-r1/share/ros_gz_sim_demos/models/vehicle/model.sdf).

Gazebo systems often use default topic naming conventions based on entity names.

In this demo:

- world name is `demo`
- model name is `vehicle`

That is why topics end up looking like:

- `/model/vehicle/cmd_vel`
- `/model/vehicle/odometry`
- `/model/vehicle/pose`
- `/world/demo/model/vehicle/joint_state`

The topic name is derived from the entity names plus the plugin/system's naming convention.

One extra clue in this demo: the comment block near the top of
[vehicle.sdf](/nix/store/sssi2c11s5rcy0ynm6in5w86xwavqxlv-ros-jazzy-ros-gz-sim-demos-1.0.22-r1/share/ros_gz_sim_demos/worlds/vehicle.sdf)
already shows example commands using:

- `/model/vehicle/cmd_vel`
- `/model/vehicle/odometry`

So sometimes the quickest path is:

1. look for comments in the world file
2. look for plugins in the model file
3. then confirm the actual live topic names with `gz topic -l` or `ros2 topic list`

## How To Trace A Topic Yourself

When a topic name is not obvious from the file you opened, use this order:

1. Start with the world file.
   Look for:
   - the world name
   - the model instance name
   - any world or model plugins attached there
2. Open the included model file.
   Look for:
   - motion / sensor plugins such as `DiffDrive`
   - explicit topic tags if present
   - otherwise assume the plugin may use a default name derived from the model name
3. Check the bridge config.
   This tells you which topic names the ROS side expects.
4. Confirm live topics from the running system.
   Use:
   ```sh
   gz topic -l
   ros2 topic list
   ```

For this specific demo, that process gives:

- world name: `demo`
- model instance name: `vehicle`
- movement plugin: `DiffDrive`
- bridged command topic: `/model/vehicle/cmd_vel`
- bridged odometry topic: `/model/vehicle/odometry`

## Who Creates What

| Thing | Created by | Where |
| --- | --- | --- |
| World named `demo` | SDF world definition | [vehicle.sdf](/nix/store/sssi2c11s5rcy0ynm6in5w86xwavqxlv-ros-jazzy-ros-gz-sim-demos-1.0.22-r1/share/ros_gz_sim_demos/worlds/vehicle.sdf) |
| Model instance named `vehicle` | `<model name="vehicle">` | [vehicle.sdf](/nix/store/sssi2c11s5rcy0ynm6in5w86xwavqxlv-ros-jazzy-ros-gz-sim-demos-1.0.22-r1/share/ros_gz_sim_demos/worlds/vehicle.sdf) |
| Robot links and joints | Model definition | [model.sdf](/nix/store/sssi2c11s5rcy0ynm6in5w86xwavqxlv-ros-jazzy-ros-gz-sim-demos-1.0.22-r1/share/ros_gz_sim_demos/models/vehicle/model.sdf) |
| Motion from velocity commands | `DiffDrive` plugin | [model.sdf](/nix/store/sssi2c11s5rcy0ynm6in5w86xwavqxlv-ros-jazzy-ros-gz-sim-demos-1.0.22-r1/share/ros_gz_sim_demos/models/vehicle/model.sdf) |
| Pose topic | `PosePublisher` plugin | [vehicle.sdf](/nix/store/sssi2c11s5rcy0ynm6in5w86xwavqxlv-ros-jazzy-ros-gz-sim-demos-1.0.22-r1/share/ros_gz_sim_demos/worlds/vehicle.sdf) |
| Joint state topic | `JointStatePublisher` plugin | [vehicle.sdf](/nix/store/sssi2c11s5rcy0ynm6in5w86xwavqxlv-ros-jazzy-ros-gz-sim-demos-1.0.22-r1/share/ros_gz_sim_demos/worlds/vehicle.sdf) |
| Odometry topic | `OdometryPublisher` plugin | [vehicle.sdf](/nix/store/sssi2c11s5rcy0ynm6in5w86xwavqxlv-ros-jazzy-ros-gz-sim-demos-1.0.22-r1/share/ros_gz_sim_demos/worlds/vehicle.sdf) |
| ROS<->Gazebo translation | `ros_gz_bridge` | [ros_gz_bridge_sdf_parser.yaml](/home/felix/doodle/gazebo_sso2/config/ros_gz_bridge_sdf_parser.yaml) |
| ROS velocity command message | `ros2 topic pub` | your shell command |

## End-To-End Message Flow

This is what happens when you publish velocity from ROS.

### ROS to Gazebo

1. Gazebo loads [vehicle.sdf](/nix/store/sssi2c11s5rcy0ynm6in5w86xwavqxlv-ros-jazzy-ros-gz-sim-demos-1.0.22-r1/share/ros_gz_sim_demos/worlds/vehicle.sdf).
2. That world creates a model instance named `vehicle`.
3. The included [model.sdf](/nix/store/sssi2c11s5rcy0ynm6in5w86xwavqxlv-ros-jazzy-ros-gz-sim-demos-1.0.22-r1/share/ros_gz_sim_demos/models/vehicle/model.sdf) attaches the `DiffDrive` plugin.
4. The bridge is configured to translate `/model/vehicle/cmd_vel`.
5. You run:

```sh
ros2 topic pub /model/vehicle/cmd_vel geometry_msgs/msg/Twist ...
```

6. The bridge converts:
   - ROS `geometry_msgs/msg/Twist`
   - to Gazebo `gz.msgs.Twist`
7. The `DiffDrive` plugin receives that Gazebo message.
8. The robot moves.

### Gazebo to ROS

1. Gazebo plugins publish pose / joint / odometry topics.
2. The bridge converts those Gazebo messages into ROS messages.
3. ROS tools like:
   - `ros2 topic echo`
   - RViz
   - your own nodes
   can then consume them.

## Practical Rule Of Thumb

When you are reading Gazebo + ROS integration code, keep these layers separate:

- SDF world/model files define entities and attach systems
- Gazebo systems/plugins create simulation behavior and Gazebo topics
- the bridge maps Gazebo topics to ROS topics
- ROS nodes publish / subscribe on the ROS side

That separation is the main thing that makes these examples initially hard to read.
