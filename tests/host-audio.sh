#!/usr/bin/env bash
# Host-side player for Vine's audio FIFO (shims/frameworks.m, VINE_AUDIO_FIFO): whenever the game
# starts an output unit it writes "<format> <rate> <channels>" to <fifo>.fmt, then opens the FIFO;
# each stream is played with pacat. Runs until the FIFO is removed.
# Usage: host-audio.sh <fifo>
FIFO=$1
while [ -p "$FIFO" ]; do
  [ -f "$FIFO.fmt" ] || { sleep 0.1; continue; }
  read -r fmt rate ch < "$FIFO.fmt"; rm -f "$FIFO.fmt"
  pacat --playback --raw --format="$fmt" --rate="$rate" --channels="$ch" --latency-msec=40 \
    --client-name=Roblox --stream-name="Roblox (Vine)" < "$FIFO"
done
