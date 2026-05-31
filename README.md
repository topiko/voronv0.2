# Voron V0.2 Bring-Up Notes

This repository contains local notes and working config for an LDO Voron V0.2 build.

The active Klipper config lives under `config/`.

Key files:
- `config/printer.cfg`: main Klipper config
- `config/V0Display.cfg`: display MCU and display hardware config
- `config/shutdown_menu.cfg`: display-driven Raspberry Pi shutdown macro
- `config/display_menu_overrides.cfg`: LCD menu label and layout overrides
- `menuconf_options/menuconf_display`: known-good Klipper `menuconfig` output for the V0 display

## Wiring And Assembly

Build and wire the printer according to the LDO docs:
- [LDO Voron V0.2 wiring guide](https://docs.ldomotors.com/voron/voron02/wiring_guide_rev_a)

Hardware note:
- The SKR Pico needs the `x-diag` and `y-diag` jumpers installed for the expected homing behavior.

## Raspberry Pi OS

Use Raspberry Pi OS Lite 32-bit.

Before first boot, make sure you have:
- enabled SSH
- configured Wi-Fi if needed
- set username/password

`rpi-imager` did not reliably write the advanced settings in this setup. If that happens again, inspect the boot partition after imaging and verify that cloud-init customization files were actually written.

## Host Software

Install KIAUH and then use it to install:
- Klipper
- Moonraker
- Mainsail

Commands:

```bash
git clone git@github.com:dw-0/kiauh.git
./kiauh/kiauh.sh
```

During installation, this setup used:
- Mainsail on port `80`

## PrusaSlicer Upload

PrusaSlicer can connect directly using the `Klipper / Moonraker` printer option.

In this setup, the Flatpak build did not resolve `voronv02.local` correctly, even though it worked in a browser.

Use the printer IP directly instead:
- `http://192.168.50.36:7125`

It is a good idea to make that IP static in the router.

## SKR Pico Flashing

Reference:
- [Voron SKR Pico Klipper guide](https://docs.vorondesign.com/build/software/skrPico_klipper.html)

Build steps:

```bash
cd ~/klipper
make menuconfig
make clean
make
```

Set `make menuconfig` to:
- Micro-controller Architecture: `Raspberry Pi RP2040`
- Communication interface: `USB`

This produces:
- `out/klipper.uf2`

To flash the Pico:
1. Install the Pico boot jumper.
2. Connect the Pico to the Raspberry Pi over USB-C.
3. Press reset.
4. Mount the mass storage device and copy `klipper.uf2`.

Example:

```bash
sudo mount /dev/sda1 /mnt
sudo cp out/klipper.uf2 /mnt
sudo umount /mnt
```

Then:
1. Remove the boot jumper.
2. Press reset again.
3. Verify the device appears under:

```bash
ls /dev/serial/by-id/*
```

Working device IDs in this setup:
- Main SKR Pico:
  - `/dev/serial/by-id/usb-Klipper_rp2040_5044340410AA1B1C-if00`
- Picobilical / Umbilical MCU:
  - `/dev/serial/by-id/usb-Klipper_rp2040_4D4E383131111B5B-if00`

To reflash an already-working RP2040 MCU from Klipper:

```bash
sudo service klipper stop
cd ~/klipper
make flash FLASH_DEVICE=/dev/serial/by-id/<insert-serial-id>
sudo service klipper start
```

Note:
- On the Picobilical, pressing reset may be needed before the device reappears.
- Avoid double-pressing reset unless you explicitly want to enter its boot mode.

## Active Config Layout

The active printer config is:
- `config/printer.cfg`

To sync the local `config/` directory to the printer's Klipper config directory, run:

```bash
./sync_configs.sh
```

This uses `rsync` to copy `config/` to `pi@voronv02.local:~/printer_data/config/` without deleting remote-only files.

This file includes:
- `mainsail.cfg`
- `V0Display.cfg`
- `shutdown_menu.cfg`
- `display_menu_overrides.cfg`

If Mainsail complains about missing `virtual_sdcard`, `pause_resume`, `display_status`, `PAUSE`, `RESUME`, or `CANCEL_PRINT`, verify that `mainsail.cfg` is included from `config/printer.cfg`.

## V0 Display

The display is working in this setup and is configured through:
- `config/V0Display.cfg`

The display MCU appears as:
- `/dev/serial/by-id/usb-Klipper_stm32f042x6_260033000243315350313520-if00`

### Display Flashing

Reference:
- [Voron V0 display flashing guide](https://github.com/VoronDesign/Voron-Hardware/blob/master/V0_Display/Documentation/Setup_and_Flashing_Guide.md)

The final working Klipper build settings for the display are captured in:
- `menuconf_options/menuconf_display`

Important working details from that config:
- MCU: `STM32F042`
- Clock reference: `Internal`
- Bootloader offset: `No bootloader`
- USB communication enabled
- USB remap enabled:
  - `CONFIG_STM32_USB_PA11_PA12_REMAP=y`

That USB remap detail was the important one for this board.

After flashing and resetting, verify the display MCU appears in:

```bash
ls /dev/serial/by-id/*
```

## Display Menu Overrides

Klipper's default LCD menu still contains old `OctoPrint` naming. This repository overrides that in:
- `config/display_menu_overrides.cfg`

Current behavior:
- `OctoPrint` is renamed to `Print`
- `Pause`, `Resume`, and `Cancel Print` use Klipper commands instead of legacy action strings
- a top-level `Power` menu is added
- the stock `Setup -> Restart` menu is hidden

Current top-level power menu entries:
- `Restart Pi`
- `Restart FW`
- `Shutdown Pi`

## Display-Driven Pi Shutdown

The shutdown logic lives in:
- `config/shutdown_menu.cfg`

It uses Moonraker's `shutdown_machine` remote method.

Current shutdown behavior:
- refuses shutdown while printing
- refuses shutdown if the hotend is above `70C`
- turns off heaters
- turns off the part fan
- disables steppers
- exits the menu
- displays `Shutting down...`
- waits briefly, then powers off the Raspberry Pi through Moonraker

This is intended as the normal no-laptop-needed shutdown path.

## Electronics Cooling Fan

The loose 24V electronics fan next to the SKR Pico is wired to the Pico fan header mapped to `gpio20`.

It is configured in `config/printer.cfg` as:

```ini
[controller_fan pcb_fan]
pin: gpio20
max_power: 1.0
kick_start_time: 0.5
stepper: stepper_x, stepper_y, stepper_z, extruder
```

This means the fan runs when the main printer steppers are enabled/active.

## Bring-Up Checklist

Once all MCUs are flashed and the config is loaded:
1. Open Mainsail.
2. Verify all MCUs connect.
3. Verify the display works.
4. Check thermistor readings are sane.
5. Check fan control.
6. Check endstop states.
7. Check motor directions.
8. Home the printer.
9. Run heater PID tuning if needed.
10. Continue with standard Voron startup calibration.

## Notes

- The active config is in `config/`, not at repository root.
- If you edit display behavior, start with:
  - `config/V0Display.cfg`
  - `config/shutdown_menu.cfg`
  - `config/display_menu_overrides.cfg`
- If you edit machine behavior, start with:
  - `config/printer.cfg`
