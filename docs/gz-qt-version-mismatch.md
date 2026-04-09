# `gz` vs `ros2 launch` Qt Version Mismatch

This note captures the specific failure where direct `gz sim ...` hit:

```text
Cannot mix incompatible Qt library (5.15.15) with this library (5.15.16)
```

while the ROS launch path:

```sh
ros2 launch ros_gz_sim gz_sim.launch.py ...
```

did not hit that same error.

## Symptom

The failing direct `gz` path showed a mixed stack:

- Qt `5.15.16` libraries coming from `/nix/store`
- Qt `5.15.15` plugins coming from the micromamba Gazebo install under:
  - `~/.local/share/gazebo-micromamba/envs/gz-sim8`

The concrete failure included paths like:

- `.../plugins/imageformats/libqsvg.so`
- `.../lib/libQt5Svg.so.5.15.15`

from the micromamba environment, while other Qt libraries were loaded from Nix.

That is enough for Qt to abort.

## Why This Happened

On this machine, interactive `zsh` has this alias:

- [zshrc](/home/felix/.zshrc#L85)

```sh
alias gz="gazebo"
```

So typing:

```sh
gz sim ...
```

in an interactive shell does **not** necessarily run the `gz` binary from the Nix ROS environment.

Instead, it can go through the system-wide `gazebo` wrapper from:

- [gazebo.nix](/home/felix/.config/dotfiles/nix/modules/packages/gazebo.nix)

That wrapper is built around micromamba and uses:

- `~/.local/share/gazebo-micromamba`

Relevant lines:

- [gazebo.nix](/home/felix/.config/dotfiles/nix/modules/packages/gazebo.nix#L20)
- [gazebo.nix](/home/felix/.config/dotfiles/nix/modules/packages/gazebo.nix#L36)
- [gazebo.nix](/home/felix/.config/dotfiles/nix/modules/packages/gazebo.nix#L183)

So the direct `gz` path and the ROS launch path were not actually using the same Gazebo / Qt stack.

## Why `ros2 launch ros_gz_sim ...` Behaved Differently

`ros2 launch ros_gz_sim gz_sim.launch.py ...` starts Gazebo from the ROS / Nix environment assembled by the project flake.

That path stays within the Nix-built ROS + Gazebo stack:

- `ros_gz_sim`
- `gz-sim-vendor`
- `gz-gui-vendor`
- Nix Qt libraries

So it avoided the specific "Qt 5.15.15 plugin + Qt 5.15.16 library" mixture that the direct `gz` path hit.

This does **not** mean ROS is doing anything special to fix Qt.

It just means the launch path stayed on one coherent dependency set.

## Why `unalias gz` Was Not Enough

`unalias gz` only removes the shell alias.

It does **not** guarantee that the rest of the process environment is clean.

If a shell session still has paths or helper wrappers that point at the micromamba Gazebo install, you can still end up mixing:

- Nix Qt libraries
- micromamba Qt plugins

So `unalias gz` is weaker than using a known-good absolute binary path.

## Safe Ways To Run Gazebo In This Repo

### 1. Prefer the ROS launch path

```sh
ros2 launch ros_gz_sim gz_sim.launch.py ...
```

This was the most reliable GUI path in this repo.

### 2. If you need direct `gz`, use the Nix binary explicitly

Use the `gz` binary from the dev-shell `ros-env`, not the shell alias.

Example pattern:

```sh
/nix/store/...-ros-env/bin/gz sim ...
```

That avoids the `gz -> gazebo` alias problem.

### 3. If you only need simulation, use server-only mode

```sh
gz sim -s -r ...
```

This avoids the GUI Qt plugin path entirely, which makes it less likely to hit GUI/plugin version conflicts.

## Practical Rule

For this repo, treat these as two different toolchains:

- **Nix ROS / Gazebo stack**
  - used by `ros2 launch ros_gz_sim ...`
- **system micromamba Gazebo stack**
  - used by the dotfiles `gazebo` wrapper

Do not assume they are interchangeable just because both expose something named `gz` or `gazebo`.

## Related Note

For the separate display / black-window issues after the correct Gazebo stack was selected, see:

- [ros-gz-sim-gui-troubleshooting.md](/home/felix/doodle/gazebo_sso2/docs/ros-gz-sim-gui-troubleshooting.md)
