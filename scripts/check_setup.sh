#!/usr/bin/env bash
# Prints what is installed and what is missing. Changes nothing.
PX4_DIR=${PX4_DIR:-$HOME/PX4-Autopilot}
WS=${WS:-$HOME/px4_ws}
pass=0; fail=0
chk() { if eval "$2" >/dev/null 2>&1; then printf '  \033[32m[OK]\033[0m   %s\n' "$1"; pass=$((pass+1));
        else printf '  \033[31m[MISS]\033[0m %s  -> %s\n' "$1" "$3"; fail=$((fail+1)); fi; }

echo "Setup check (PX4_DIR=$PX4_DIR, WS=$WS)"
chk "Ubuntu 24.04"                 '[ "$(. /etc/os-release; echo $VERSION_ID)" = 24.04 ]' "other versions are untested"
chk "ROS 2 Jazzy"                  '[ -f /opt/ros/jazzy/setup.bash ]'                       "./install.sh ros"
chk "ros_gz bridge"                '[ -d /opt/ros/jazzy/share/ros_gz_bridge ]'              "sudo apt install ros-jazzy-ros-gz"
chk "colcon"                       'command -v colcon'                                      "sudo apt install python3-colcon-common-extensions"
chk "Gazebo (gz sim)"              'gz sim --versions'                                      "./install.sh px4 (PX4's ubuntu.sh installs Gazebo Harmonic)"
chk "PX4 SITL binary"              '[ -x "$PX4_DIR/build/px4_sitl_default/bin/px4" ]'       "./install.sh px4"
chk "MicroXRCEAgent"               'command -v MicroXRCEAgent'                              "./install.sh agent"
chk "px4_msgs built in workspace"  '[ -d "$WS/install/px4_msgs" ]'                          "./install.sh ws"
chk "tmux"                         'command -v tmux'                                        "sudo apt install tmux"
if [ -d "$PX4_DIR/msg" ] && [ -d "$WS/src/px4_msgs/msg" ]; then
    chk "px4_msgs matches PX4 firmware" \
        'diff -q <(cd "$PX4_DIR/msg" && cat *.msg versioned/*.msg 2>/dev/null | md5sum) <(cd "$WS/src/px4_msgs/msg" && for f in "$PX4_DIR"/msg/*.msg "$PX4_DIR"/msg/versioned/*.msg; do [ -f "$f" ] && cat "$(basename "$f")"; done 2>/dev/null | md5sum)' \
        "./install.sh ws  (re-syncs messages from PX4)"
fi
echo "  $pass ok, $fail missing"
[ $fail -eq 0 ]
