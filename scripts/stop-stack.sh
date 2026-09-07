#!/bin/bash
# Stop Linpac stack processes started by start-stack.sh.

set -u

echo "Stopping AX.25 / Direwolf stack..."

sudo killall -q linpac || true
sudo killall -q mheardd || true
sudo killall -q kissattach || true
sudo killall -q socat || true
sudo killall -q direwolf || true

if command -v ifconfig >/dev/null; then
  sudo ifconfig ax0 down 2>/dev/null || true
fi

sudo rm -f /tmp/kisstnc /var/lock/LinPac.0

echo "Stack stopped."
echo "If the terminal is garbled after a Linpac crash, run:  stty sane"
