#!/bin/bash
# Start Direwolf + socat PTY + kissattach for Linpac.
# Run from the Pi as a user in the sudo group. Do not start Linpac from this script.

set -euo pipefail

PORT_NAME="${AX25_PORT:-vhf}"
DW_CONF="${DIREWOLF_CONF:-/etc/ax25/direwolf.conf}"
KISS_LINK="${KISS_LINK:-/tmp/kisstnc}"
KISS_TCP="${KISS_TCP:-127.0.0.1:8001}"

if [[ ! -f "$DW_CONF" ]]; then
  echo "Missing Direwolf config: $DW_CONF" >&2
  exit 1
fi

if ! grep -q "^${PORT_NAME}[[:space:]]" /etc/ax25/axports; then
  echo "AX.25 port '${PORT_NAME}' is not defined in /etc/ax25/axports" >&2
  exit 1
fi

sudo modprobe ax25
sudo modprobe mkiss

if pgrep -x direwolf >/dev/null; then
  echo "Direwolf is already running." >&2
  exit 1
fi

echo "Starting Direwolf..."
direwolf -t 0 -c "$DW_CONF" >/tmp/direwolf.log 2>&1 &
sleep 3

if ! pgrep -x direwolf >/dev/null; then
  echo "Direwolf failed to start. See /tmp/direwolf.log" >&2
  exit 1
fi

rm -f "$KISS_LINK"
echo "Bridging KISS TCP ${KISS_TCP} to ${KISS_LINK}..."
socat PTY,raw,echo=0,link="${KISS_LINK}",mode=666 TCP:"${KISS_TCP}" >/tmp/socat-kiss.log 2>&1 &
sleep 2

if [[ ! -e "$KISS_LINK" ]]; then
  echo "socat did not create ${KISS_LINK}. See /tmp/socat-kiss.log" >&2
  exit 1
fi

KISS_DEV="$(readlink -f "$KISS_LINK")"
echo "Attaching AX.25 port ${PORT_NAME} on ${KISS_DEV}..."
sudo kissattach "$KISS_DEV" "$PORT_NAME"
sudo kissparms -c 1 -p "$PORT_NAME"

if ! pgrep -x mheardd >/dev/null; then
  sudo mheardd || true
fi

echo
echo "Stack is up. AX.25 port: ${PORT_NAME}"
echo "Check:  ip link show type ax25"
echo "Then in another terminal:  linpac"
echo "Logs: /tmp/direwolf.log  /tmp/socat-kiss.log"
