# Procedure: Linpac on a Raspberry Pi 3B+ with SignaLink USB and Kenwood TM-D700

This procedure builds a **1200-baud connected-packet** station. The SignaLink USB is an external sound-card TNC interface on the D700 **DATA** port. Direwolf provides the modem. Linux AX.25 presents a radio port. Linpac is the terminal.

Do **not** use the D700’s built-in TNC for this setup. Do **not** install the Debian/Raspberry Pi OS `linpac` package; it is old and known to break.

Replace `N0CALL` with your callsign everywhere it appears.

---

## 0. What you are building

```
Pi 3B+ USB
    -> SignaLink USB (sound card + VOX PTT)
        -> SLUSB6PM / SLCAB6PM 6-pin mini-DIN
            -> TM-D700 DATA connector (front of the main unit, not the head)
                -> FM 1200-baud AFSK on the radio's TX band

Software on the Pi:
    Direwolf  -- software TNC, KISS on TCP 8001
    socat     -- TCP KISS to a PTY (Bookworm-safe)
    kissattach -- PTY to kernel AX.25 port "vhf"
    linpac    -- packet terminal on that AX.25 port
```

## 1. Parts and power

| Item | Notes |
| --- | --- |
| Raspberry Pi 3B+ | 1 GB RAM is enough. Use a 5 V / 2.5 A official-class supply. |
| microSD | 16 GB or larger, Class 10 / A1. |
| SignaLink USB | Cable combo **SLUSB6PM** (or SignaLink USB + **SLCAB6PM**). Jumper module **SLMOD6PM**. |
| TM-D700 / D700A | DATA jack is a 6-pin mini-DIN on the **main unit**. |
| Dummy load or antenna | Required for TX tests. |

Plug the SignaLink into a Pi USB port directly. A cheap unpowered hub is a common cause of USB-audio dropouts on the 3B+.

## 2. SignaLink jumpers and knobs

1. Power the SignaLink **off** (USB unplugged).
2. Open the SignaLink. Install the **SLMOD6PM** module in JP1 (or wire JP1 for a 6-pin mini-DIN data port).
3. For **1200 baud**, leave the module on **12** (speaker/RX audio from radio pin 5, PR1). Do **not** move SPKR to pin 4 unless you are deliberately running 9600 baud.
4. Close the unit. Set the front knobs:
   - **DLY**: fully counterclockwise (minimum delay).
   - **TX**: about 8–10 o’clock to start.
   - **RX**: about 10–12 o’clock to start.
5. Cable: SignaLink RJ-45 radio jack → 6-pin mini-DIN → D700 **DATA**.
6. Power the radio **off** while mating the DATA plug.

Pin functions on the D700 DATA jack (for reference):

| Pin | Name | Function |
| --- | --- | --- |
| 1 | PKD | TX audio into the radio |
| 2 | GND | Ground |
| 3 | PKS | PTT / packet standby (mic mute while transmitting) |
| 4 | PR9 | 9600-baud RX audio (not used at 1200) |
| 5 | PR1 | 1200-baud RX audio |
| 6 | SQC | Squelch output (SignaLink does not use this) |

## 3. Kenwood TM-D700 settings

Turn the radio on after the DATA cable is seated.

1. **Turn the built-in TNC off.** Press **TNC** until TNC / PACKET / APRS indicators are gone. You want a normal FM dual-band radio, not APRS mode.
2. Select the band you will use for packet as the **control / TX band** (the band that shows PTT). With an external TNC, Menu **1-6-1 DATA BAND** is ignored; packet follows the TX band.
3. Mode: **FM**. On a TM-D700E, do **not** use narrow TX deviation on that band.
4. CTCSS / DCS: off unless your local packet channel requires a tone.
5. Menu **1-9-6 DATA SPEED**: **1200 bps**. This menu applies only to an external TNC on the DATA port.
6. Set frequency to your local **1200-baud packet** channel (examples in North America are often near 145.010 / 145.030 / 145.050 — use what your area actually uses). APRS 144.390 is the wrong channel for a Linpac BBS/node QSO unless that is specifically what you intend.
7. Squelch: set just above the noise. DATA-port 1200 audio is not the speaker volume knob.

## 4. Raspberry Pi OS

Install **Raspberry Pi OS Lite (32-bit)** — the current Trixie / Debian 13 image. The Pi 3B+ has 1 GB of RAM; Lite leaves that for Direwolf and Linpac, and 32-bit uses less of it than 64-bit. Skip Desktop and Full. SignaLink PTT is VOX, so Trixie’s GPIO changes do not affect this station.

In Raspberry Pi Imager:

1. Device: **Raspberry Pi 3**.
2. OS: **Raspberry Pi OS (other)** → **Raspberry Pi OS Lite (32-bit)**.
3. If that image gives you trouble later, use **Raspberry Pi OS (Legacy)** → **Lite (32-bit)** (Bookworm). Do not use Ubuntu or a desktop image.
4. In Imager customization: hostname, username, Wi-Fi or Ethernet, locale, and **enable SSH**.

Boot the Pi, SSH in, then either run the installer (recommended) or follow the remaining sections by hand.

**Installer (does sections 4–10):** clone this repo on the Pi and run:

```bash
sudo apt update
sudo apt full-upgrade -y
sudo reboot
```

After reboot:

```bash
git clone https://github.com/buryd/Linpac_D700.git
cd Linpac_D700
bash scripts/install-linpac.sh --call N0CALL
```

Replace `N0CALL` with your callsign. The script updates packages, adds `net.ifnames=0` to `cmdline.txt`, detects the SignaLink card name, writes `/etc/ax25/direwolf.conf` and `/etc/ax25/axports`, builds Linpac, and installs `start-stack.sh` / `stop-stack.sh`. Do **not** type `ADEVICE` or `net.ifnames=0` at the bash prompt.

If the installer cannot see the SignaLink, plug it in and pass the card name from `arecord -l`:

```bash
bash scripts/install-linpac.sh --call N0CALL --card CODEC
```

Then continue from **section 11** (bring the stack up). The sections below are the same steps, written out for a manual install.

Disable predictable network interface names. Long `enx…` names can crash Linpac and AX.25 utilities. On Trixie and Bookworm the file is `/boot/firmware/cmdline.txt` (older images used `/boot/cmdline.txt`). Append to the **single existing line**:

```text
net.ifnames=0
```

Reboot. `ip link` should show `eth0` (and `wlan0` if Wi-Fi is used).

Add your user to the audio group (SignaLink is a USB sound card):

```bash
sudo usermod -aG audio,dialout "$USER"
# log out and back in
```

## 5. Identify the SignaLink on USB

Plug the SignaLink in. The front PWR LED should light.

```bash
lsusb
arecord -l
aplay -l
```

You want a USB audio device, often named `Device`, `CODEC`, or `USB PnP Sound Device`. Note the **card name**, not only `card 1`. HDMI and Bluetooth can steal card numbers after a reboot.

Set ALSA levels on that card (replace `Device` with your card name):

```bash
alsamixer -c Device
```

Set PCM / Speaker / Mic / Capture near 70–80%. Do the fine adjustment later with the SignaLink **TX** and **RX** knobs, not with huge ALSA swings.

Confirm capture:

```bash
arecord -D plughw:Device,0 -f S16_LE -r 44100 -c 1 -d 3 /tmp/rx-test.wav
```

If the radio is receiving FM noise or a packet burst, the WAV file should not be silent (`soxi` / `aplay` if you install `sox`).

## 6. Install build tools, Direwolf, and AX.25

```bash
sudo apt install -y \
  git build-essential autoconf automake libtool pkg-config \
  libncurses-dev zlib1g-dev perl python3 \
  direwolf socat \
  libax25 libax25-dev ax25-apps ax25-tools \
  screen
```

Do **not** install `linpac` from apt.

Debian renamed some AX.25 binaries. Linpac still looks for `listen`. Create a compatibility name and allow the monitor to run without root:

```bash
if [[ -x /usr/bin/axlisten && ! -e /usr/bin/listen ]]; then
  sudo ln -s /usr/bin/axlisten /usr/bin/listen
fi
sudo chmod 4755 /usr/bin/axlisten
[[ -e /usr/bin/listen ]] && sudo chmod 4755 /usr/bin/listen
```

`chmod 4755` is reset when `ax25-apps` is upgraded; re-apply it after those upgrades.

Optional but recommended later: rebuild libax25 / ax25-apps / ax25-tools from [ve7fet/linuxax25](https://github.com/ve7fet/linuxax25) if you hit stack bugs. Distro packages are enough to get on the air.

## 7. Configure Direwolf

```bash
sudo mkdir -p /etc/ax25
sudo cp direwolf.conf.example /etc/ax25/direwolf.conf
sudo nano /etc/ax25/direwolf.conf
```

Use the template in this repo. Required edits:

- `ADEVICE plughw:Device,0` — card name from `arecord -l`
- `MYCALL N0CALL-1` — your call, SSID **-1** is conventional for the TNC/port
- No `PTT` line (SignaLink VOX)

Test receive only (radio on the packet frequency, squelch as above):

```bash
direwolf -t 0 -c /etc/ax25/direwolf.conf
```

You should see:

- audio device attached
- `1200 baud, AFSK 1200 & 2200 Hz`
- `PTT not configured` (expected)
- `Ready to accept KISS client application on port 8001`

If a local packet station beacons, Direwolf should print decoded frames. Ctrl+C to stop.

If nothing decodes: raise SignaLink **RX** slightly, confirm jumper **12** not **96**, confirm Menu 1-9-6 is 1200, confirm the radio is on FM on the TX band.

## 8. Configure Linux AX.25

```bash
sudo cp axports.example /etc/ax25/axports
sudo nano /etc/ax25/axports
```

One data line, tabs or spaces as in the template:

```text
vhf        N0CALL-1    19200   256     2       SignaLink USB / TM-D700 1200
```

The first column (`vhf`) is the port name Linpac will ask for. The callsign must match Direwolf’s `MYCALL`.

## 9. Compile Linpac from the develop branch

```bash
cd ~
git clone https://git.code.sf.net/p/linpac/linpac linpac-src
cd linpac-src
git checkout develop

sudo apt install -y autoconf automake libtool
autoreconf --install
./configure --prefix=/usr
```

If `autoreconf` complains about LIBTOOL, run `libtoolize` then `autoreconf --install` again.

```bash
make -j4
sudo mkdir -p \
  /usr/share/linpac/contrib \
  /usr/share/doc/linpac/czech \
  /usr/share/linpac/macro/cz \
  /usr/libexec/linpac \
  /var/ax25/mail
sudo make install
sudo ldconfig
sudo chown "$USER" /var/ax25/mail
```

Hold the apt package so a later `apt upgrade` cannot overlay this build:

```bash
sudo apt-mark hold linpac || true
```

Confirm:

```bash
which linpac
linpac -h || true
```

If SourceForge git is unreachable, use the GitHub mirror:

```bash
git clone https://github.com/srl295/linpac.git linpac-src
```

## 10. Install the start/stop scripts

From this repository (copy the `scripts` directory onto the Pi, or recreate the files):

```bash
chmod +x start-stack.sh stop-stack.sh
sudo cp start-stack.sh stop-stack.sh /usr/local/bin/
```

`start-stack.sh` starts Direwolf **without** `-p`, then uses `socat` to feed `kissattach`. That avoids the common Bookworm error:

```text
kissattach: Error setting line discipline: TIOCSETD
```

## 11. Bring the stack up (order matters)

Use **three** terminals (or `screen` windows). SSH is fine.

**Terminal 1 — radio stack**

```bash
/usr/local/bin/start-stack.sh
```

Expect `ax0` (or similar) to exist:

```bash
ip link show type ax25
```

**Terminal 2 — optional live decode**

```bash
axlisten -a   # or: listen -a
```

**Terminal 3 — Linpac** (first run only; it writes `~/.linpac`)

```bash
linpac
```

Answer the first-run prompts:

| Prompt | What to enter |
| --- | --- |
| Callsign without SSID | `N0CALL` |
| Home BBS callsign | A real local BBS if you have one, otherwise a placeholder such as `N0CALL-1` |
| Name of the port | `vhf` (must match `/etc/ax25/axports`) |
| Digipeaters | Enter for none |
| Hierarchical address | A valid-looking path for your region, e.g. `#WPA.PA.USA.NOAM` |

The home-BBS fields are required even if you are not using ax25mail-utils. They do not start automatic mail polling until you configure that later.

## 12. First on-air checks

**Receive.** With `axlisten -a` running, a local node or BBS beacon should print. Direwolf’s log (`/tmp/direwolf.log` if you used the start script) should show the same frames.

**Transmit / PTT.** In Linpac, send a UI test (unproto). Exact macro names vary by version; a typical command is:

```text
:u vhf CQ testing N0CALL
```

or use the unproto / beacon feature from the Linpac help (`:help`). Watch the SignaLink **PTT** LED and the D700 TX indicator. They should key for the burst and drop quickly (DLY at minimum).

**Connected QSO.** In Linpac:

```text
:c CALL-SSID
```

Use a station you can hear (node, BBS, or a second TNC). Disconnect with `:d`. Exit Linpac with **Alt+X**.

If Linpac crashes and the terminal is unusable:

```bash
stty sane
rm -f /var/lock/LinPac.0
```

## 13. Audio alignment (do this on a dummy load)

Goal: clean 1200/2200 Hz AFSK, about 3–3.5 kHz FM deviation, not overdriven.

1. Leave ALSA near 70–80%.
2. Have a second receiver (or WebSDR / local operator) listen.
3. Raise SignaLink **TX** until the packet burst is solid, then stop. If the other station reports “overdeviated” or Direwolf on a second radio shows clipping, turn **TX** down.
4. For RX: watch Direwolf’s decode. If it rarely decodes stations you can hear by ear, raise **RX**. If the audio bar is pegged or tones look square, lower **RX**.
5. Keep **DLY** at minimum so the radio unkeys as soon as the frame ends.

The D700 DATA port is sensitive. Small TX-knob changes matter more than ALSA.

## 14. Daily use

```bash
/usr/local/bin/start-stack.sh
linpac
```

When finished:

```bash
# exit Linpac first (Alt+X)
/usr/local/bin/stop-stack.sh
```

Useful Linpac commands:

| Command | Action |
| --- | --- |
| `:c CALL-SSID` | Connect |
| `:d` | Disconnect |
| `:help` | Help |
| Alt+X | Quit |

Run Linpac inside `screen` if you SSH in:

```bash
screen -S packet
linpac
# detach: Ctrl+A, D
```

## 15. Troubleshooting

| Symptom | Likely cause |
| --- | --- |
| SignaLink PWR LED dark | USB cable, Pi under-voltage (rainbow/lightning icon), bad PSU |
| `arecord -l` has no USB card | Cable, try the other USB port, `dmesg \| tail` |
| Direwolf: no decode | Wrong frequency/band, TNC still on, jumper on 96, Menu 1-9-6 not 1200, RX too low/high |
| PTT never keys | DLY/TX both at zero, wrong jumper module, DATA plug not fully seated |
| PTT sticks after the frame | Turn **DLY** fully CCW |
| Radio TXs but nobody decodes you | TX too high (overdrive) or too low; confirm FM not NFM on D700E |
| `kissattach: TIOCSETD` | Use `start-stack.sh` (socat method), load `mkiss`, do not use `direwolf -p` on Bookworm |
| Linpac segfault at start | AX.25 port not up, `net.ifnames=0` missing, wrong port name vs `axports` |
| Monitor window empty | `listen` / `axlisten` not setuid; recreate the symlink after `ax25-apps` upgrades |
| Mic audio on packet TX | Normal if PKS is not asserting; check SLMOD6PM and PTT LED |

## 16. What this procedure does not do

- It does not use the D700 COM/serial port or the internal TNC in KISS mode.
- It does not configure APRS, Winlink, NetROM, or a PBBS.
- It does not install ax25mail-utils (Linpac’s optional BBS mail relay). Add that later if you want automatic FBB-style mail.

## References

- Linpac (develop): https://github.com/srl295/linpac and https://sourceforge.net/projects/linpac/
- Direwolf: https://github.com/wb2osz/direwolf
- VE7FET AX.25 stack: https://github.com/ve7fet/linuxax25
- David Ranch, Raspberry Pi AX.25/Linpac: https://www.trinityos.com/HAM/CentosDigitalModes/RPi/rpi2-setup.html
- Kenwood TM-D700 specialized communications manual (DATA pinout, Menu 1-9-6)
- Tigertronics SignaLink USB cable list: TM-D700 uses **SLUSB6PM** + **SLMOD6PM** on the DATA port
