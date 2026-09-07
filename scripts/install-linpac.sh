#!/bin/bash
# Install Direwolf, AX.25, and Linpac on a Raspberry Pi for a SignaLink USB
# + Kenwood TM-D700 station. Run this ON the Pi as a normal user with sudo.
#
#   git clone https://github.com/buryd/Linpac_D700.git
#   cd Linpac_D700
#   bash scripts/install-linpac.sh --call N0CALL
#
# Optional:  --card CODEC   --port vhf   --yes   --skip-build

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

CALL=""
CARD=""
PORT_NAME="vhf"
ASSUME_YES=0
SKIP_BUILD=0
NEED_REBOOT=0

usage() {
  cat <<'EOF'
Usage: bash scripts/install-linpac.sh --call N0CALL [options]

  --call CALLSIGN   Your callsign without SSID (required)
  --card NAME       ALSA card name from arecord -l (example: CODEC)
  --port NAME       AX.25 port name (default: vhf)
  --yes             Do not ask confirmation questions
  --skip-build      Skip compiling Linpac (packages and config only)
  -h, --help        Show this help

This script edits files. Do not type ADEVICE or net.ifnames=0 at the shell.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --call) CALL="${2^^}"; shift 2 ;;
    --card) CARD="$2"; shift 2 ;;
    --port) PORT_NAME="$2"; shift 2 ;;
    --yes) ASSUME_YES=1; shift ;;
    --skip-build) SKIP_BUILD=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
  esac
done

if [[ ${EUID} -eq 0 ]]; then
  echo "Run as a normal user (the script will call sudo)." >&2
  exit 1
fi

if [[ -z "$CALL" ]]; then
  read -r -p "Callsign without SSID: " CALL
  CALL="${CALL^^}"
fi

if [[ ! "$CALL" =~ ^[A-Z0-9]{3,7}$ ]]; then
  echo "Callsign '${CALL}' does not look valid." >&2
  exit 1
fi

MYCALL="${CALL}-1"

confirm() {
  local prompt="$1"
  if [[ "$ASSUME_YES" -eq 1 ]]; then
    return 0
  fi
  local reply
  read -r -p "${prompt} [y/N] " reply
  [[ "${reply}" =~ ^[Yy]$ ]]
}

echo
echo "Linpac / SignaLink / TM-D700 installer"
echo "  User:     ${USER}"
echo "  Callsign: ${MYCALL}"
echo "  AX.25:    ${PORT_NAME}"
echo
echo "Hardware (do this yourself; the script cannot):"
echo "  - SignaLink SLMOD6PM jumper on 12, DLY fully counterclockwise"
echo "  - DATA cable on the D700 main unit, built-in TNC OFF"
echo "  - Menu 1-9-6 DATA SPEED = 1200, FM, TX band on your packet frequency"
echo "  - SignaLink USB plugged into the Pi (PWR LED on)"
echo

if ! confirm "Continue with software install?"; then
  exit 0
fi

sudo -v

echo
echo "==> Updating packages"
sudo apt update
sudo DEBIAN_FRONTEND=noninteractive apt install -y \
  git build-essential autoconf automake libtool pkg-config \
  libncurses-dev zlib1g-dev perl python3 \
  direwolf socat \
  libax25 libax25-dev ax25-apps ax25-tools \
  screen alsa-utils usbutils

if dpkg -s linpac >/dev/null 2>&1; then
  echo "Removing the apt linpac package (it is too old)."
  sudo apt remove -y linpac || true
fi

echo
echo "==> Adding ${USER} to audio and dialout"
sudo usermod -aG audio,dialout "${USER}"

echo
echo "==> Setting net.ifnames=0 in the kernel command line"
CMDLINE=""
for f in /boot/firmware/cmdline.txt /boot/cmdline.txt; do
  if [[ -f "$f" ]]; then
    CMDLINE="$f"
    break
  fi
done

if [[ -z "$CMDLINE" ]]; then
  echo "Could not find cmdline.txt; skip this step and add net.ifnames=0 by hand." >&2
else
  if grep -q 'net.ifnames=0' "$CMDLINE"; then
    echo "Already present in ${CMDLINE}"
  else
    current="$(tr -d '\n' < "$CMDLINE" | sed 's/[[:space:]]*$//')"
    printf '%s net.ifnames=0\n' "$current" | sudo tee "$CMDLINE" >/dev/null
    echo "Appended net.ifnames=0 to ${CMDLINE}"
    NEED_REBOOT=1
  fi
fi

echo
echo "==> AX.25 listen compatibility"
if [[ -x /usr/bin/axlisten && ! -e /usr/bin/listen ]]; then
  sudo ln -s /usr/bin/axlisten /usr/bin/listen
fi
[[ -x /usr/bin/axlisten ]] && sudo chmod 4755 /usr/bin/axlisten
[[ -e /usr/bin/listen ]] && sudo chmod 4755 /usr/bin/listen

echo
echo "==> USB / SignaLink"
lsusb || true
if lsusb | grep -qi '08bb:2904'; then
  echo "Found Texas Instruments PCM2904 (typical SignaLink USB): 08bb:2904"
else
  echo "Did not see 08bb:2904. Plug the SignaLink in if it is not already."
fi

echo
echo "ALSA capture devices (arecord -l):"
arecord -l || true
echo
echo "ALSA playback devices (aplay -l):"
aplay -l || true

if [[ -z "$CARD" ]]; then
  mapfile -t CARDS < <(arecord -l 2>/dev/null | sed -n 's/^card [0-9][0-9]*: \([^ ]*\) \[.*/\1/p' | grep -v -E '^(b1|b2|Headphones|vc4hdmi|vc4hdmi0|vc4hdmi1)$' || true)
  if [[ ${#CARDS[@]} -eq 1 ]]; then
    CARD="${CARDS[0]}"
    echo
    echo "Using ALSA card name: ${CARD}"
  elif [[ ${#CARDS[@]} -gt 1 ]]; then
    echo
    echo "More than one USB/ALSA card. Pass --card NAME or type it now."
    printf '  %s\n' "${CARDS[@]}"
    read -r -p "ALSA card name: " CARD
  else
    echo
    echo "No USB audio card found. You can still write the config and plug the SignaLink later."
    read -r -p "ALSA card name [Device]: " CARD
    CARD="${CARD:-Device}"
  fi
fi

echo
echo "==> Writing /etc/ax25/direwolf.conf and /etc/ax25/axports"
sudo mkdir -p /etc/ax25

if [[ -f /etc/ax25/direwolf.conf ]]; then
  sudo cp /etc/ax25/direwolf.conf "/etc/ax25/direwolf.conf.bak.$(date +%Y%m%d%H%M%S)"
fi
if [[ -f /etc/ax25/axports ]]; then
  sudo cp /etc/ax25/axports "/etc/ax25/axports.bak.$(date +%Y%m%d%H%M%S)"
fi

sudo tee /etc/ax25/direwolf.conf >/dev/null <<EOF
# Written by install-linpac.sh — SignaLink USB + Kenwood TM-D700
ADEVICE  plughw:${CARD},0
ACHANNELS 1

CHANNEL 0
MYCALL ${MYCALL}
MODEM 1200

# SignaLink keys the radio with VOX. Do not set a PTT line.

AGWPORT 8000
KISSPORT 8001
EOF

sudo tee /etc/ax25/axports >/dev/null <<EOF
# name     callsign    speed   paclen  window  description
${PORT_NAME}        ${MYCALL}    19200   256     2       SignaLink USB / TM-D700 1200
EOF

echo "Direwolf ADEVICE is plughw:${CARD},0"
echo "AX.25 port ${PORT_NAME}  ${MYCALL}"

echo
echo "==> Installing start/stop scripts"
sudo install -m 0755 "${SCRIPT_DIR}/start-stack.sh" /usr/local/bin/start-stack.sh
sudo install -m 0755 "${SCRIPT_DIR}/stop-stack.sh" /usr/local/bin/stop-stack.sh

if [[ "$SKIP_BUILD" -eq 0 ]]; then
  echo
  echo "==> Building Linpac from git (develop)"
  SRC="${HOME}/linpac-src"
  if [[ ! -d "${SRC}/.git" ]]; then
    rm -rf "$SRC"
    if ! git clone https://git.code.sf.net/p/linpac/linpac "$SRC"; then
      echo "SourceForge clone failed; trying GitHub."
      git clone https://github.com/srl295/linpac.git "$SRC"
    fi
  fi
  cd "$SRC"
  git fetch --all --tags || true
  git checkout develop || git checkout master
  if ! autoreconf --install; then
    libtoolize
    autoreconf --install
  fi
  ./configure --prefix=/usr
  make -j2
  sudo mkdir -p \
    /usr/share/linpac/contrib \
    /usr/share/doc/linpac/czech \
    /usr/share/linpac/macro/cz \
    /usr/libexec/linpac \
    /var/ax25/mail
  sudo make install
  sudo ldconfig
  sudo chown "${USER}" /var/ax25/mail
  sudo apt-mark hold linpac || true
else
  echo "Skipping Linpac build (--skip-build)."
  sudo mkdir -p /var/ax25/mail
  sudo chown "${USER}" /var/ax25/mail
fi

echo
echo "Install finished."
echo
echo "Next:"
if [[ "$NEED_REBOOT" -eq 1 ]]; then
  echo "  1. sudo reboot   (required after net.ifnames=0)"
  echo "  2. Log in again (audio group is applied on a new login)."
else
  echo "  1. Log out and back in so the audio group applies."
fi
echo "  3. /usr/local/bin/start-stack.sh"
echo "  4. In another terminal: linpac"
echo
echo "Do not type ADEVICE or net.ifnames=0 at the shell. They live in"
echo "  /etc/ax25/direwolf.conf  and  ${CMDLINE:-/boot/firmware/cmdline.txt}"
echo
echo "First-run Linpac prompts:"
echo "  Callsign without SSID:  ${CALL}"
echo "  Home BBS:               ${MYCALL}  (or a real local BBS)"
echo "  Port name:              ${PORT_NAME}"
echo "  Digipeaters:            Enter for none"
echo "  Hierarchical address:   e.g. #WPA.PA.USA.NOAM"
