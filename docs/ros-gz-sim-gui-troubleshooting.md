# `ros_gz_sim` GUI Troubleshooting On This Machine

This note captures the failure modes we hit while trying to run:

```sh
ros2 launch ros_gz_sim gz_sim.launch.py gz_args:="shapes.sdf"
```

and the fixes that made it work on this NixOS + `niri` setup.

## Working Command

Once the shell had access to the active graphical session, this worked:

```sh
export GZ_IP=127.0.0.1
export GZ_PARTITION="gazebo${UID}"
QT_QPA_PLATFORM=xcb ros2 launch ros_gz_sim gz_sim.launch.py gz_args:="shapes.sdf"
```

## Failure Mode 1: Qt Could Not Open A Display

The first error looked like:

```text
qt.qpa.xcb: could not connect to display
Could not load the Qt platform plugin "xcb" in "" even though it was found.
```

On this machine, that happened because the shell running `ros2 launch ...` was on the same VT as the graphical session, but did not inherit the graphical session environment.

Symptoms from that shell:

```sh
echo "$DISPLAY"
echo "$WAYLAND_DISPLAY"
echo "$XDG_SESSION_TYPE"
```

Output:

```text


tty
```

That means:

- no X11 display was exported
- no Wayland display was exported
- the shell identified itself as a plain text TTY shell

However, the actual user session was already graphical:

- session type was `wayland`
- `niri` was running
- the user session environment contained:
  - `DISPLAY=:0`
  - `WAYLAND_DISPLAY=wayland-1`
  - `XDG_RUNTIME_DIR=/run/user/1000`

So the fix for this stage was to run Gazebo from a terminal that actually lives inside the `niri` session, or manually export the same display variables into the current shell.

## Failure Mode 2: Gazebo Opened A Black Window

After the display variables were fixed, Gazebo opened a window, but it was black.

The command that fixed that was:

```sh
export GZ_IP=127.0.0.1
export GZ_PARTITION="gazebo${UID}"
QT_QPA_PLATFORM=xcb ros2 launch ros_gz_sim gz_sim.launch.py gz_args:="shapes.sdf"
```

## Why `GZ_IP=127.0.0.1` Helped

This is the important part.

The Jazzy `ros_gz_sim` launch path does not set `GZ_IP`. It launches combined-mode Gazebo with the resource/plugin path environment, but leaves Gazebo transport addressing alone.

Relevant file in this repo:

- `ros_gz_sim/launch/gz_sim.launch.py.in`

By contrast, your older Gazebo wrapper already forced Gazebo transport onto loopback:

```sh
export GZ_IP="''${GZ_IP:-127.0.0.1}"
```

Relevant file on this machine:

- `/home/felix/.config/dotfiles/nix/modules/packages/gazebo.nix`

`ros_gz_sim`'s own test suite also pins Gazebo transport to localhost:

```python
SetEnvironmentVariable(name='GZ_IP', value='127.0.0.1')
```

That strongly suggests the black window was a Gazebo GUI-to-server transport/discovery problem rather than a Qt rendering problem.

Inference:

- the GUI process opened successfully
- the GUI did not attach cleanly to the server / simulation state
- constraining Gazebo transport to `127.0.0.1` made discovery deterministic on this machine

## Why `GZ_PARTITION` Is Also Worth Setting

`GZ_PARTITION="gazebo${UID}"` isolates this user's Gazebo transport namespace from any other Gazebo processes running under other users or sessions.

It was not the main fix, but it is a sensible companion to `GZ_IP=127.0.0.1` and matches the intent of your older wrapper.

## Why `QT_QPA_PLATFORM=xcb` Was Used

This machine is running `niri` on Wayland, but it also has Xwayland available.

Using:

```sh
QT_QPA_PLATFORM=xcb
```

forces Qt to use the X11 backend through Xwayland instead of trying to decide between Wayland and X11 automatically.

That is useful here because:

- the shell originally lacked Wayland/X11 session variables
- Gazebo / Qt behavior was more predictable once X11 was selected explicitly

## What `ros_gz_sim` Is Doing Differently From The Older Wrapper

Your older wrapper did two things the plain `ros2 launch ros_gz_sim gz_sim.launch.py ...` path does not do by default:

1. It set `GZ_IP=127.0.0.1`.
2. It had a split-mode fallback that launched server and GUI as separate processes with different `RMT_PORT`s.

Relevant lines in the older wrapper:

- `GZ_IP=127.0.0.1`
- server `RMT_PORT=1500`
- gui `RMT_PORT=1501`

In the current `ros_gz_sim` workflow, the first fix was enough, so split mode was not needed.

## Recommended Workflow

If you are running from a proper terminal inside the active `niri` session, use:

```sh
export GZ_IP=127.0.0.1
export GZ_PARTITION="gazebo${UID}"
QT_QPA_PLATFORM=xcb ros2 launch ros_gz_sim gz_sim.launch.py gz_args:="shapes.sdf"
```

If the shell does not have GUI session variables, first confirm:

```sh
echo "DISPLAY=$DISPLAY"
echo "WAYLAND_DISPLAY=$WAYLAND_DISPLAY"
echo "XDG_SESSION_TYPE=$XDG_SESSION_TYPE"
```

If those are empty or `tty`, you are not actually launching from the compositor environment even if you are on the same VT.

## References

- `ros_gz_sim/launch/gz_sim.launch.py.in`
- `ros_gz_sim/test/test_gz_simulation_interfaces.launch.py`
- `/home/felix/.config/dotfiles/nix/modules/packages/gazebo.nix`
