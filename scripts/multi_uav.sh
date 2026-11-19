#!/usr/bin/env bash
# Start N PX4 x500 quadcopters in ONE Gazebo world + the XRCE-DDS agent, in tmux.
#
#   ./scripts/multi_uav.sh [N=3] [SPACING_M=6]
#
# Every vehicle i gets:  ROS 2 namespace /uav_i   (e.g. /uav_1/fmu/out/vehicle_status_v4)
#                        MAV_SYS_ID = i+1
#                        spawn point on a line:  x = i * SPACING, y = 0  (Gazebo ENU, metres)
# Options (env vars):  HEADLESS=1  -> no Gazebo GUI      NO_ATTACH=1 -> don't attach to tmux
#                      PX4_DIR     -> default ~/PX4-Autopilot
#                      WORLD       -> Gazebo world name (default: default)
# Stop everything with ./scripts/stop_all.sh (closing tmux alone leaves gz sim running).
set -e

N=${1:-3}
SPACING=${2:-6}
PX4_DIR=${PX4_DIR:-$HOME/PX4-Autopilot}
WORLD=${WORLD:-default}
SESSION=uavs
PX4_BIN=$PX4_DIR/build/px4_sitl_default/bin/px4

[ -x "$PX4_BIN" ] || { echo "PX4 SITL not built: $PX4_BIN  (run ./install.sh px4)"; exit 1; }
command -v MicroXRCEAgent >/dev/null || { echo "MicroXRCEAgent not found (run ./install.sh agent)"; exit 1; }
command -v tmux >/dev/null || { echo "tmux not found: sudo apt install tmux"; exit 1; }
if tmux has-session -t $SESSION 2>/dev/null; then
    echo "tmux session '$SESSION' already running. Stop it first: ./scripts/stop_all.sh"; exit 1
fi

# Common PX4 environment for every instance:
#   PX4_SYS_AUTOSTART=4001       x500 airframe
#   PX4_UXRCE_DDS_NS=uav_i       topics under /uav_i/fmu/... (instance 0 included)
#   PX4_PARAM_NAV_DLL_ACT=0      no ground-station link required (development only!)
#   PX4_PARAM_COM_RC_IN_MODE=4   no RC transmitter required
#   PX4_GZ_NO_FOLLOW=1           don't lock the Gazebo camera to one vehicle
px4_cmd() {
    local i=$1 extra=$2
    echo "cd $PX4_DIR && $extra PX4_SYS_AUTOSTART=4001 PX4_SIM_MODEL=gz_x500 \
PX4_GZ_MODEL_POSE=$((i * SPACING)),0 PX4_UXRCE_DDS_NS=uav_$i \
PX4_PARAM_NAV_DLL_ACT=0 PX4_PARAM_COM_RC_IN_MODE=4 PX4_GZ_NO_FOLLOW=1 \
$PX4_BIN -i $i; bash"
}

tmux new-session -d -s $SESSION -n agent "MicroXRCEAgent udp4 -p 8888; bash"
# Instance 0 starts the Gazebo server (and GUI unless HEADLESS=1)
tmux new-window -t $SESSION -n px4_0 "$(px4_cmd 0 "PX4_GZ_WORLD=$WORLD HEADLESS=${HEADLESS:-}")"
# The others attach to the running Gazebo (STANDALONE), staggered so spawns don't collide
for ((i = 1; i < N; i++)); do
    tmux new-window -t $SESSION -n px4_$i "sleep $((8 + 3 * i)); $(px4_cmd $i "PX4_GZ_STANDALONE=1")"
done

echo "Started $N vehicles in tmux session '$SESSION'."
echo "Check:  ros2 topic list | grep uav_     (vehicles appear ~20-40 s after start)"
if [ -z "${NO_ATTACH:-}" ]; then tmux attach -t $SESSION; fi
