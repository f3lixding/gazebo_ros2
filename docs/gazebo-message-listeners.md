# Gazebo Message Listeners

This note answers two related questions:

- what an SDF file can declare about topics
- what code actually receives `/model/vehicle/cmd_vel` and turns it into motion

## What SDF Can And Cannot Declare

An SDF file can often declare:

- topic names
- plugin configuration
- sensor configuration
- frame names
- model / link / joint names

An SDF file usually does **not** define a brand-new message schema inline.

Instead:

- the **plugin / system / sensor** decides what message type it uses
- the SDF usually only configures the topic name and other settings

So the pattern is:

- SDF chooses the topic name
- the plugin chooses the message type
- the code chooses what to do with the message

## Example: Custom Topic In SDF

The `DiffDrive` system supports a custom command topic.

That is documented in [DiffDrive.hh](/nix/store/dnprpmvm4fd94rc7akm9icn7hh7djx6h-gz-sim8_8.11.0/src/systems/diff_drive/DiffDrive.hh#L57):

- `<topic>` overrides the command topic
- `<odom_topic>` overrides the odometry topic
- `<tf_topic>` overrides the transform topic
- `<frame_id>` and `<child_frame_id>` override TF / odometry frame names

Concrete example from Gazebo's own test world:
[diff_drive_custom_topics.sdf](/nix/store/dnprpmvm4fd94rc7akm9icn7hh7djx6h-gz-sim8_8.11.0/test/worlds/diff_drive_custom_topics.sdf#L224)

```xml
<plugin
  filename="gz-sim-diff-drive-system"
  name="gz::sim::systems::DiffDrive">
  <left_joint>left_wheel_joint</left_joint>
  <right_joint>right_wheel_joint</right_joint>
  <wheel_separation>1.25</wheel_separation>
  <wheel_radius>0.3</wheel_radius>
  <topic>/model/foo/cmdvel</topic>
  <odom_topic>/model/bar/odom</odom_topic>
</plugin>
```

That does **not** define a new message type.
It tells the existing `DiffDrive` system:

- subscribe on `/model/foo/cmdvel`
- publish odometry on `/model/bar/odom`

## Example: Sensor Topic In SDF

Sensors also often let you choose the topic name with `<topic>`.

Example:
[gpu_lidar_retro_values_sensor.sdf](/nix/store/10224vk96mcvzdsjdfd6x2rn4vrpb4la-ros-jazzy-gz-sim-vendor-0.0.10-r1/share/gz/gz-sim8/worlds/gpu_lidar_retro_values_sensor.sdf#L180)

```xml
<sensor name='gpu_lidar' type='gpu_lidar'>
  <topic>lidar</topic>
  <update_rate>10</update_rate>
  ...
</sensor>
```

Again:

- SDF chooses the topic name `lidar`
- the sensor type `gpu_lidar` determines what kind of Gazebo message gets published

## What Receives `/model/vehicle/cmd_vel`

In the vehicle demo, the concrete consumer is the Gazebo `DiffDrive` system attached in:
[model.sdf](/nix/store/sssi2c11s5rcy0ynm6in5w86xwavqxlv-ros-jazzy-ros-gz-sim-demos-1.0.22-r1/share/ros_gz_sim_demos/models/vehicle/model.sdf#L171)

```xml
<plugin
  filename="ignition-gazebo-diff-drive-system"
  name="ignition::gazebo::systems::DiffDrive">
  <left_joint>left_wheel_joint</left_joint>
  <right_joint>right_wheel_joint</right_joint>
  <wheel_separation>1.25</wheel_separation>
  <wheel_radius>0.3</wheel_radius>
  ...
</plugin>
```

The actual C++ subscription logic is in:
[DiffDrive.cc](/nix/store/dnprpmvm4fd94rc7akm9icn7hh7djx6h-gz-sim8_8.11.0/src/systems/diff_drive/DiffDrive.cc#L335)

```cpp
std::vector<std::string> topics;
if (_sdf->HasElement("topic"))
{
  topics.push_back(_sdf->Get<std::string>("topic"));
}
topics.push_back("/model/" + this->dataPtr->model.Name(_ecm) + "/cmd_vel");
auto topic = validTopic(topics);

this->dataPtr->node.Subscribe(topic, &DiffDrivePrivate::OnCmdVel,
    this->dataPtr.get());
```

This means:

1. if SDF specified `<topic>`, use that
2. otherwise default to `/model/<model-name>/cmd_vel`
3. subscribe to that Gazebo topic

## What The Callback Does

When a `gz.msgs.Twist` arrives, the callback is:
[DiffDrive.cc](/nix/store/dnprpmvm4fd94rc7akm9icn7hh7djx6h-gz-sim8_8.11.0/src/systems/diff_drive/DiffDrive.cc#L637)

```cpp
void DiffDrivePrivate::OnCmdVel(const msgs::Twist &_msg)
{
  std::lock_guard<std::mutex> lock(this->mutex);
  if (this->enabled)
  {
    this->targetVel = _msg;
  }
}
```

So the callback does not move the robot directly.

It just stores the most recent target velocity.

## What Actually Makes The Car Move

The motion happens in two later stages.

### 1. Convert Twist To Wheel Speeds

[DiffDrive.cc](/nix/store/dnprpmvm4fd94rc7akm9icn7hh7djx6h-gz-sim8_8.11.0/src/systems/diff_drive/DiffDrive.cc#L605)

```cpp
linVel = this->targetVel.linear().x();
angVel = this->targetVel.angular().z();

this->rightJointSpeed =
  (linVel + angVel * this->wheelSeparation / 2.0) / this->wheelRadius;
this->leftJointSpeed =
  (linVel - angVel * this->wheelSeparation / 2.0) / this->wheelRadius;
```

This is the differential-drive kinematics step:

- linear velocity + angular velocity
- converted into left and right wheel angular velocities

### 2. Apply Those Wheel Speeds To The Joints

[DiffDrive.cc](/nix/store/dnprpmvm4fd94rc7akm9icn7hh7djx6h-gz-sim8_8.11.0/src/systems/diff_drive/DiffDrive.cc#L390)

```cpp
_ecm.SetComponentData<components::JointVelocityCmd>(joint,
  {this->dataPtr->leftJointSpeed});

_ecm.SetComponentData<components::JointVelocityCmd>(joint,
  {this->dataPtr->rightJointSpeed});
```

This is what actually tells Gazebo's simulation engine:

- spin the left wheel joints at this speed
- spin the right wheel joints at that speed

Then physics takes over and the car moves.

So the full chain is:

1. message arrives on `/model/vehicle/cmd_vel`
2. `OnCmdVel` stores it
3. `UpdateVelocity` computes wheel speeds
4. `PreUpdate` writes joint velocity commands
5. physics moves the model

## If You Want To Write Something That Listens

There are two different places you can listen.

### Option 1: Listen On The ROS Side

Use this if you want a normal ROS node.

Minimal Python example:

```python
import rclpy
from rclpy.node import Node
from geometry_msgs.msg import Twist


class CmdVelListener(Node):
    def __init__(self):
        super().__init__('cmd_vel_listener')
        self.create_subscription(
            Twist,
            '/model/vehicle/cmd_vel',
            self.on_cmd_vel,
            10,
        )

    def on_cmd_vel(self, msg: Twist):
        self.get_logger().info(
            f'linear.x={msg.linear.x:.3f} angular.z={msg.angular.z:.3f}'
        )


def main():
    rclpy.init()
    node = CmdVelListener()
    rclpy.spin(node)
    node.destroy_node()
    rclpy.shutdown()


if __name__ == '__main__':
    main()
```

That listens to the **ROS** topic.

If Gazebo is on the other side, you also need the bridge running.

### Option 2: Listen Inside Gazebo

Use this if you want custom simulator behavior, like `DiffDrive`.

The pattern is the one used by `DiffDrive` itself:

```cpp
this->node.Subscribe("/model/my_robot/cmd_vel",
    &MySystemPrivate::OnCmdVel, this);

void MySystemPrivate::OnCmdVel(const gz::msgs::Twist &_msg)
{
  this->targetVel = _msg;
}
```

Then in your update step, use `targetVel` to:

- set joint velocity commands
- apply forces
- move links
- publish other simulator-side topics

That is not a ROS node.
That is a Gazebo system plugin.

## The Key Separation

The most important distinction is:

- ROS listener:
  - receives ROS messages
  - usually written with `rclpy` or `rclcpp`
  - needs the bridge if the original source is Gazebo

- Gazebo listener:
  - receives Gazebo Transport messages
  - usually written as a Gazebo system / plugin
  - acts directly on simulation state

The vehicle demo uses the second pattern.
