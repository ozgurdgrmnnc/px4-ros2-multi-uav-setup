#!/usr/bin/env bash
# One-shot installer: ROS 2 Jazzy + Gazebo Harmonic + PX4-Autopilot (SITL) +
# Micro XRCE-DDS Agent + a ROS 2 workspace with px4_msgs matched to your PX4.
# Target: Ubuntu 24.04 (native or WSL2). Safe to re-run: finished steps are skipped.
#
#   ./install.sh            # everything
#   ./install.sh ros px4    # only some steps: ros, px4, agent, ws, bashrc
#
# Paths can be changed with environment variables:
#   PX4_DIR (default ~/PX4-Autopilot)  WS (default ~/px4_ws)  AGENT_DIR (default ~/Micro-XRCE-DDS-Agent)
set -euo pipefail

PX4_DIR=${PX4_DIR:-$HOME/PX4-Autopilot}
WS=${WS:-$HOME/px4_ws}
AGENT_DIR=${AGENT_DIR:-$HOME/Micro-XRCE-DDS-Agent}
AGENT_TAG=${AGENT_TAG:-v2.4.3}
STEPS=${*:-ros px4 agent ws bashrc}

c() { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
ok() { printf '\033[1;32m    %s\033[0m\n' "$*"; }
want() { [[ " $STEPS " == *" $1 "* ]]; }

. /etc/os-release
if [[ "${VERSION_ID:-}" != "24.04" ]]; then
    echo "Warning: tested on Ubuntu 24.04, you have ${PRETTY_NAME:-unknown}. Continue? [y/N]"
    read -r a; [[ "$a" == [yY] ]] || exit 1
fi
echo "This script uses sudo (apt install, make install). Steps: $STEPS"
echo "PX4_DIR=$PX4_DIR  WS=$WS  AGENT_DIR=$AGENT_DIR"
read -r -p "Continue? [y/N] " a; [[ "$a" == [yY] ]] || exit 1

# ---------------------------------------------------------------- ROS 2 + Gazebo
if want ros; then
    c "ROS 2 Jazzy + Gazebo Harmonic (ros-gz)"
    if [ -f /opt/ros/jazzy/setup.bash ]; then
        ok "ROS 2 Jazzy already installed"
    else
        sudo apt update
        sudo apt install -y software-properties-common curl
        sudo add-apt-repository -y universe
        # Official method: the ros2-apt-source package adds the ROS key + repo
        ROS_APT_SOURCE_VERSION=$(curl -fsS https://api.github.com/repos/ros-infrastructure/ros-apt-source/releases/latest | grep -F '"tag_name"' | awk -F'"' '{print $4}')
        [[ "$ROS_APT_SOURCE_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "Could not read ros-apt-source version"; exit 1; }
        tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT   # private dir, not a predictable /tmp path
        curl -fL -o "$tmp/ros2-apt-source.deb" \
            "https://github.com/ros-infrastructure/ros-apt-source/releases/download/${ROS_APT_SOURCE_VERSION}/ros2-apt-source_${ROS_APT_SOURCE_VERSION}.${VERSION_CODENAME}_all.deb"
        dpkg-deb -I "$tmp/ros2-apt-source.deb" | grep -q "Package: ros2-apt-source" || { echo "Unexpected package"; exit 1; }
        sudo apt install -y "$tmp/ros2-apt-source.deb"
        sudo apt update
        sudo apt install -y ros-jazzy-desktop
    fi
    sudo apt install -y ros-jazzy-ros-gz python3-colcon-common-extensions \
        python3-numpy python3-scipy python3-matplotlib python3-pytest tmux git
fi

# ---------------------------------------------------------------- PX4
if want px4; then
    c "PX4-Autopilot (first build takes a while)"
    if [ ! -d "$PX4_DIR" ]; then
        git clone https://github.com/PX4/PX4-Autopilot.git --recursive "$PX4_DIR"
    else
        ok "$PX4_DIR exists, skipping clone"
    fi
    bash "$PX4_DIR/Tools/setup/ubuntu.sh" --no-nuttx
    # Gazebo Python bindings (used by gz-transport based tools); repo is added by ubuntu.sh
    sudo apt install -y python3-gz-transport13 python3-gz-msgs10 || \
        echo "    (python3-gz-* not found yet; re-run './install.sh ros' after a restart)"
    if [ ! -x "$PX4_DIR/build/px4_sitl_default/bin/px4" ]; then
        (cd "$PX4_DIR" && make px4_sitl_default)
    fi
    ok "PX4 SITL built: $PX4_DIR/build/px4_sitl_default/bin/px4"
    echo "    If this is the first install: restart the shell (WSL: 'wsl --shutdown' in PowerShell)."
fi

# ---------------------------------------------------------------- XRCE-DDS Agent
if want agent; then
    c "Micro XRCE-DDS Agent $AGENT_TAG (PX4 <-> ROS 2 bridge)"
    if command -v MicroXRCEAgent >/dev/null; then
        ok "MicroXRCEAgent already installed"
    else
        [ -d "$AGENT_DIR" ] || git clone -b "$AGENT_TAG" https://github.com/eProsima/Micro-XRCE-DDS-Agent.git "$AGENT_DIR"
        mkdir -p "$AGENT_DIR/build" && cd "$AGENT_DIR/build"
        cmake .. && make -j"$(nproc)"
        sudo make install
        sudo ldconfig /usr/local/lib/
    fi
fi

# ---------------------------------------------------------------- workspace
if want ws; then
    c "ROS 2 workspace $WS with px4_msgs matched to your PX4"
    mkdir -p "$WS/src"
    [ -d "$WS/src/px4_msgs" ] || git clone https://github.com/PX4/px4_msgs.git "$WS/src/px4_msgs"
    if [ -d "$PX4_DIR/msg" ]; then
        # px4_msgs MUST match the firmware, otherwise topics silently do not arrive
        cp "$PX4_DIR"/msg/*.msg "$WS/src/px4_msgs/msg/"
        cp "$PX4_DIR"/msg/versioned/*.msg "$WS/src/px4_msgs/msg/" 2>/dev/null || true
        cp "$PX4_DIR"/srv/*.srv "$WS/src/px4_msgs/srv/" 2>/dev/null || true
        ok "px4_msgs synced from $PX4_DIR"
    fi
    set +u; source /opt/ros/jazzy/setup.bash; set -u
    (cd "$WS" && colcon build --symlink-install)
fi

# ---------------------------------------------------------------- bashrc
if want bashrc; then
    c "Auto-source ROS 2 and the workspace in every terminal"
    grep -qxF "source /opt/ros/jazzy/setup.bash" ~/.bashrc || echo "source /opt/ros/jazzy/setup.bash" >> ~/.bashrc
    line="[ -f $WS/install/setup.bash ] && source $WS/install/setup.bash"
    grep -qxF "$line" ~/.bashrc || echo "$line" >> ~/.bashrc
    ok "~/.bashrc updated"
fi

c "Done. Check everything with: ./scripts/check_setup.sh"
