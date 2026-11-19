# PX4 + ROS 2 Jazzy + Gazebo Harmonic: Multi-UAV Simulation Setup

Set up a **multi-drone simulation** on **Ubuntu 24.04 (native or WSL2)** in a few commands:
PX4 SITL x500 quadcopters in one Gazebo world, each in its own ROS 2 namespace, bridged
with Micro XRCE-DDS. This is the setup I use for my multi-UAV projects
([multi-uav-target-assignment](https://github.com/ozgurdgrmnnc/multi-uav-target-assignment),
[cbba-multi-drone-ros2](https://github.com/ozgurdgrmnnc/cbba-multi-drone-ros2)).

🇹🇷 Türkçe kılavuz: [KURULUM_TR.md](KURULUM_TR.md)

| Component | Version tested |
|---|---|
| Ubuntu | 24.04 LTS (WSL2 on Windows 11) |
| ROS 2 | Jazzy |
| Gazebo | Harmonic (gz sim 8) |
| PX4-Autopilot | main (v1.18 dev) |
| Micro XRCE-DDS Agent | v2.4.3 |

## Quick start

```bash
git clone https://github.com/ozgurdgrmnnc/px4-ros2-multi-uav-setup.git
cd px4-ros2-multi-uav-setup
./install.sh                 # ROS 2 + Gazebo + PX4 + XRCE agent + workspace (asks before sudo)
# first install only: restart the shell (WSL: run `wsl --shutdown` in PowerShell, reopen Ubuntu)
./scripts/check_setup.sh     # verifies everything, prints the fix for anything missing
./scripts/multi_uav.sh 3     # 3 drones in Gazebo, each under /uav_0, /uav_1, /uav_2
./scripts/stop_all.sh        # always stop with this (closing tmux leaves gz sim running)
```

In another terminal:

```bash
ros2 topic list | grep uav_
ros2 topic echo --once /uav_1/fmu/out/vehicle_status_v4
```

`install.sh` can also run single steps: `./install.sh ros`, `px4`, `agent`, `ws`, `bashrc`.
Paths: `PX4_DIR` (default `~/PX4-Autopilot`), `WS` (default `~/px4_ws`).

## What `multi_uav.sh` does

```
tmux session "uavs"
├─ agent   MicroXRCEAgent udp4 -p 8888          (one agent serves all vehicles)
├─ px4_0   PX4 SITL instance 0 -> starts Gazebo, spawns x500 at (0, 0)
├─ px4_1   instance 1 -> attaches to running Gazebo (PX4_GZ_STANDALONE=1), spawns at (6, 0)
└─ px4_N   ...
```

| Setting | Why |
|---|---|
| `PX4_UXRCE_DDS_NS=uav_i` | every vehicle's topics live under `/uav_i/fmu/...` |
| `-i i` | instance number, gives `MAV_SYS_ID = i+1` and unique ports |
| `PX4_GZ_STANDALONE=1` | instances 1..N reuse the Gazebo started by instance 0 |
| `PX4_PARAM_NAV_DLL_ACT=0`, `PX4_PARAM_COM_RC_IN_MODE=4` | no ground station / RC required to arm (**simulation only**) |
| staggered `sleep` | spawning all vehicles at once can make some fail to appear |

Options: `HEADLESS=1` (no GUI, much faster on WSL), `NO_ATTACH=1`, `WORLD=<name>`,
second argument = spacing in metres (`./scripts/multi_uav.sh 4 10`).

## Things that cost me hours (so they don't cost you)

- **px4_msgs must match your PX4 firmware.** If they differ, topics silently never arrive.
  `install.sh ws` copies the `.msg` files from your PX4 checkout into `px4_msgs`;
  `check_setup.sh` tells you if they drifted after a PX4 update.
- **Topic names carry a version suffix** on recent PX4: `vehicle_status_v4`, `vehicle_local_position_v1`, ...
- **QoS:** PX4 publishes `/fmu/out/*` as **BEST_EFFORT**. A default (RELIABLE) subscriber gets nothing.
  On the command line: `ros2 topic echo --qos-reliability best_effort ...`
- **NED vs ENU:** PX4 uses NED (z down), ROS/Gazebo use ENU (z up). Convert every position and yaw.
- **Offboard mode:** stream `OffboardControlMode` + `TrajectorySetpoint` continuously
  (≥ 2 Hz, 10 Hz recommended) *before* switching to offboard and the whole time after.
- **Stale ROS graph:** if `ros2 topic list` shows old topics, run `ros2 daemon stop`.
- **WSL2:** the Gazebo GUI works through WSLg; if it is slow, use `HEADLESS=1` or fewer vehicles.

## Troubleshooting

| Symptom | Check |
|---|---|
| No `/uav_*` topics | Is the `agent` window showing client sessions? `tmux attach -t uavs`, `Ctrl+b 0` |
| Vehicle won't arm | `px4_i` window: look for `Preflight Fail` |
| "session already running" | `./scripts/stop_all.sh` |
| Second vehicle missing | Increase the stagger or start fewer vehicles |

## License

MIT
