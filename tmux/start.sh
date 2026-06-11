#!/bin/bash
# Plain-tmux session script (one window per section below; panes are split and
# their commands typed via send-keys). Edit the send-keys lines to change what
# runs in each pane; ./kill.sh stops everything.

SESSION_NAME=simulation

# absolute path to this script's directory; every pane starts here
SCRIPT=$(readlink -f "$0")
SCRIPTPATH=$(dirname "$SCRIPT")

# commands executed first in every pane
PRE_WINDOW='export UAV_NAME=uav1; export RUN_TYPE=simulation; export UAV_TYPE=my_drone'
SETUP="cd $SCRIPTPATH; $PRE_WINDOW"

if [ -n "$TMUX" ]; then
  echo "Already inside tmux, detach first."
  exit 1
fi

if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
  echo "Session $SESSION_NAME already exists; attach with 'tmux a -t $SESSION_NAME' or stop it with ./kill.sh."
  exit 1
fi

# ---------------- window: roscore ----------------
read W_roscore P <<< "$(tmux new-session -d -s "$SESSION_NAME" -n "roscore" -x 250 -y 50 -P -F '#{window_id} #{pane_id}')"
tmux send-keys -t "$P" "$SETUP; "'roscore' Enter
tmux select-layout -t "$W_roscore" tiled

# ---------------- window: gazebo ----------------
read W_gazebo P <<< "$(tmux new-window -t "$SESSION_NAME" -n "gazebo" -P -F '#{window_id} #{pane_id}')"
tmux send-keys -t "$P" "$SETUP; "'waitForRos; roslaunch pairs_uav_gazebo_simulation simulation.launch world_name:=grass_plane spawner_config:=./config/spawner_config.yaml gui:=true' Enter
P=$(tmux split-window -t "$W_gazebo" -P -F '#{pane_id}')
tmux select-layout -t "$W_gazebo" tiled
tmux send-keys -t "$P" "$SETUP; "'waitForControl; gz camera -c gzclient_camera -f $UAV_NAME; history -s gz camera -c gzclient_camera -f $UAV_NAME' Enter
tmux select-layout -t "$W_gazebo" tiled

# ---------------- window: status ----------------
read W_status P <<< "$(tmux new-window -t "$SESSION_NAME" -n "status" -P -F '#{window_id} #{pane_id}')"
tmux send-keys -t "$P" "$SETUP; "'waitForHw; roslaunch pairs_uav_status status.launch' Enter
tmux select-layout -t "$W_status" tiled

# ---------------- window: spawn ----------------
read W_spawn P <<< "$(tmux new-window -t "$SESSION_NAME" -n "spawn" -P -F '#{window_id} #{pane_id}')"
tmux send-keys -t "$P" "$SETUP; "'waitForGazebo; rosservice call /pairs_drone_spawner/spawn "1 --$UAV_TYPE --enable-ground-truth --enable-rangefinder --enable-custom-monochrome-camera"' Enter
tmux select-layout -t "$W_spawn" tiled

# ---------------- window: hw_api ----------------
read W_hw_api P <<< "$(tmux new-window -t "$SESSION_NAME" -n "hw_api" -P -F '#{window_id} #{pane_id}')"
tmux send-keys -t "$P" "$SETUP; "'waitForTime; roslaunch pairs_uav_px4_api api.launch' Enter
tmux select-layout -t "$W_hw_api" tiled

# ---------------- window: core ----------------
read W_core P <<< "$(tmux new-window -t "$SESSION_NAME" -n "core" -P -F '#{window_id} #{pane_id}')"
tmux send-keys -t "$P" "$SETUP; "'waitForHw; roslaunch pairs_uav_core core.launch platform_config:=./config/platform_config.yaml custom_config:=./config/custom_config.yaml world_config:=./config/world_config.yaml network_config:=./config/network_config.yaml' Enter
tmux select-layout -t "$W_core" tiled

# ---------------- window: takeoff ----------------
read W_takeoff P <<< "$(tmux new-window -t "$SESSION_NAME" -n "takeoff" -P -F '#{window_id} #{pane_id}')"
tmux send-keys -t "$P" "$SETUP; "'waitForHw; roslaunch pairs_uav_autostart automatic_start.launch' Enter
P=$(tmux split-window -t "$W_takeoff" -P -F '#{pane_id}')
tmux select-layout -t "$W_takeoff" tiled
tmux send-keys -t "$P" "$SETUP; "'waitForControl; rosservice call /$UAV_NAME/hw_api/arming 1; sleep 2; rosservice call /$UAV_NAME/hw_api/offboard' Enter
tmux select-layout -t "$W_takeoff" tiled

# ---------------- window: goto ----------------
read W_goto P <<< "$(tmux new-window -t "$SESSION_NAME" -n "goto" -P -F '#{window_id} #{pane_id}')"
tmux send-keys -t "$P" "$SETUP; "'history -s rosservice call /$UAV_NAME/control_manager/goto \"goal: \[0.0, 10.0, 1.5, 0.0\]\"' Enter
tmux select-layout -t "$W_goto" tiled

# ---------------- window: kill (press enter inside to stop the session) ----------------
read W_kill P <<< "$(tmux new-window -t "$SESSION_NAME" -n "kill" -P -F '#{window_id} #{pane_id}')"
tmux send-keys -t "$P" "$SCRIPTPATH/kill.sh"

# mouse support (select panes / scroll with the mouse)
tmux set-option -t "$SESSION_NAME" mouse on

tmux select-window -t "$W_status"
tmux -2 attach-session -t "$SESSION_NAME"
