# Verifying Gazebo Plugin Loads

The side panel is not a reliable source of truth for whether a plugin loaded.

Use this workflow instead.

## 1. Check verbose logs

Start Gazebo with verbose logging and search for the plugin name, class name, or load errors.

```sh
gazebo building_robot.sdf -v 4 2>&1 | rg 'DiffDrive|plugin|error|failed'
```

If you launch with `gz sim` in your environment, use the same pattern:

```sh
gz sim building_robot.sdf -v 4 2>&1 | rg 'DiffDrive|plugin|error|failed'
```

## 2. Check the plugin's side effects

The real test is whether the plugin produces the behavior it is supposed to produce.

For system plugins such as `gz::sim::systems::DiffDrive`, check for:

- new topics
- model motion
- odometry
- sensors or components becoming active

Example:

```sh
gz topic -l | rg 'cmd_vel|odom'
gz topic -t /cmd_vel -m gz.msgs.Twist -p 'linear: {x: 1.0}'
```

If the plugin is working, the model should react and any expected topics should exist.

## 3. If `gz topic` is rejected, check which `gz` you are running

In some environments, `gz` is wrapped so that it always dispatches into `sim`.
When that happens, a valid command such as:

```sh
gz topic -t /cmd_vel -m gz.msgs.Twist -p 'linear: {x: 1.0}'
```

can fail with an error coming from `cmdsim8.rb` instead of the transport tool.

Check what your shell resolves:

```sh
type -a gz
```

If the error mentions `cmdsim8.rb`, your shell is likely invoking the simulator wrapper instead of the generic Gazebo CLI.

In the micromamba environment used here, `topic` is provided by `gz-transport`, not by `gz-sim`. The installed dispatcher configuration is:

- `sim` -> `cmdsim8`
- `topic` -> `cmdtransport13`
- `service` -> `cmdtransport13`

On this machine, the Nix `gazebo` launcher is also a wrapper around that micromamba environment. It supports these explicit entry points:

- `gazebo gz ...`
- `gazebo sim ...`
- `gazebo shell ...`

Unknown arguments are treated as `sim`, which is why calling `gz topic ...` directly can end up in the simulator parser.

Use the wrapper to run transport commands inside the same FHS environment:

```sh
gazebo gz --commands
gazebo gz topic -l
gazebo gz topic -t /cmd_vel -m gz.msgs.Twist -p 'linear: {x: 1.0}'
```

For ad hoc inspection inside the wrapped environment:

```sh
gazebo shell -lc 'type -a gz && gz --commands'
```

## 4. For custom plugins, emit a startup log

For plugins you write yourself, the most ergonomic check is to log one unmistakable startup line in `Load` or `Configure`.

That gives you a fast yes/no answer in the verbose log without depending on the UI.

## 5. Treat "loaded" and "working" as separate checks

A plugin can load and still not behave correctly because of bad configuration, missing entities, or wrong joint/topic names.

Use both of these checks:

- `loaded`: visible in verbose logs
- `working`: visible through expected runtime behavior

## DiffDrive in this repo

The DiffDrive plugin is configured in [building_robot.sdf](/home/felix/doodle/gazebo_sso2/building_robot.sdf#L64). It is a model system plugin, so it should be validated by logs and robot behavior, not by whether it appears in the side panel.
