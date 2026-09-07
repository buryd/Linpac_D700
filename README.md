# Linpac on Raspberry Pi 3B+ with SignaLink USB and Kenwood TM-D700

This project is a bench procedure for a **1200-baud AX.25 packet** station:

**Raspberry Pi 3B+ → SignaLink USB → Kenwood TM-D700 DATA port → Direwolf → Linux AX.25 → Linpac**

The SignaLink is the radio interface (audio + VOX PTT). Direwolf is the software TNC. Linpac is the packet terminal. The D700’s built-in TNC is left **off**.

## Documents

| File | Purpose |
| --- | --- |
| [PROCEDURE.md](PROCEDURE.md) | Full install and first-QSO procedure |
| [scripts/install-linpac.sh](scripts/install-linpac.sh) | Run on the Pi to install packages, write configs, and build Linpac |
| [config/direwolf.conf.example](config/direwolf.conf.example) | Direwolf config template |
| [config/axports.example](config/axports.example) | Linux AX.25 port template |
| [scripts/start-stack.sh](scripts/start-stack.sh) | Start Direwolf, KISS, and AX.25 |
| [scripts/stop-stack.sh](scripts/stop-stack.sh) | Tear the stack down |

On the Pi (after Raspberry Pi OS Lite is installed and SSH works):

```bash
git clone https://github.com/buryd/Linpac_D700.git
cd Linpac_D700
bash scripts/install-linpac.sh --call N0CALL
```

Replace `N0CALL` with your callsign. The installer writes `ADEVICE` and `net.ifnames=0` into the correct files — do not type those at the shell.

## What you will need

- Raspberry Pi 3B+ with a 5 V / 2.5 A (or better) supply
- Raspberry Pi OS Lite **32-bit** (Trixie / Debian 13). Bookworm Lite 32-bit is the fallback.
- Tigertronics SignaLink USB with **SLUSB6PM** / **SLCAB6PM** cable and **SLMOD6PM** jumper module
- Kenwood TM-D700 / TM-D700A (DATA 6-pin mini-DIN on the main unit)
- Your amateur radio license and a local 1200-baud packet frequency
