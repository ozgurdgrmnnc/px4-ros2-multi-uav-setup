#!/usr/bin/env bash
# Stop everything started by multi_uav.sh. gz sim is started in the background
# by PX4, so killing tmux alone leaves it running and the next start collides.
tmux kill-session -t uavs 2>/dev/null || true
pkill -f "^gz sim" 2>/dev/null || true
pkill -x px4 2>/dev/null || true
pkill -x MicroXRCEAgent 2>/dev/null || true
echo "Simulation stopped."
