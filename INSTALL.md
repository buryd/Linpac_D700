# Install on the Raspberry Pi

SSH into the Pi, then run:

```bash
sudo apt update
sudo apt install -y git
git clone https://github.com/buryd/Linpac_D700.git
cd Linpac_D700
bash scripts/install-linpac.sh --call N0CALL
```

Replace `N0CALL` with your callsign (no SSID). Example for KC4JIR:

```bash
bash scripts/install-linpac.sh --call KC4JIR
```

If the SignaLink is already plugged in, the script can detect the ALSA card name. If it cannot, pass it from `arecord -l` (the word after `card 1:`):

```bash
bash scripts/install-linpac.sh --call KC4JIR --card CODEC
```

After the script finishes, reboot if it changed `cmdline.txt`:

```bash
sudo reboot
```

Then:

```bash
/usr/local/bin/start-stack.sh
```

In a second terminal:

```bash
linpac
```
