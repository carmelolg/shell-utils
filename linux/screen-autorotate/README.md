# Linux Screen Autorotate

Part of [shell-utils](../../README.md).

A Bash utility that automatically rotates your Linux screen and touchscreen
input based on device orientation. It reads accelerometer data via
`iio-sensor-proxy` and applies the correct rotation with `xrandr` and
`xinput`.

## Project Structure

```
screen-autorotate/              # inside shell-utils/linux/
├── config/
│   └── config.conf      # User-editable configuration (display name, log path)
├── lib/
│   └── rotate.sh        # Rotation library (rotate function)
├── src/
│   └── autorotate.sh    # Main entry-point script
├── install.sh           # Automated installation script
└── README.md
```

## Features

- **Automatic screen rotation** – detects orientation changes and rotates the
  display accordingly.
- **Dynamic input remapping** – remaps all `xinput` devices to the rotated
  display automatically.
- **Configurable** – display name and log path are kept in a separate
  configuration file.
- **Startup integration** – `install.sh` creates an XDG autostart entry so the
  script runs on every login.

## Prerequisites

- Linux with an accelerometer (most modern laptops and tablets)
- Required packages:
  - `iio-sensor-proxy`
  - `inotify-tools`
  - `x11-xserver-utils` (provides `xrandr`)
  - `xinput`

## Installation

### Automated

```bash
git clone https://github.com/carmelolg/shell-utils.git
cd shell-utils/linux/screen-autorotate
bash install.sh
```

`install.sh` will:
1. Install the required packages via `apt-get`.
2. Copy the project to `/opt/linux-screen-autorotate`.
3. Create an XDG autostart entry at `~/.config/autostart/autorotate.desktop`.

### Manual

1. **Install dependencies:**

   ```bash
   sudo apt-get install iio-sensor-proxy inotify-tools x11-xserver-utils xinput
   ```

2. **Clone the repository:**

   ```bash
   git clone https://github.com/carmelolg/shell-utils.git
   cd shell-utils/linux/screen-autorotate
   ```

3. **Edit the configuration:**

   Open `config/config.conf` and set `DNAME` to your display name (find it
   with `xrandr`).

4. **Make the script executable:**

   ```bash
   chmod +x src/autorotate.sh
   ```

5. **Add to startup:**

   Add `src/autorotate.sh` to your desktop environment's startup applications.

## Usage

Run manually:

```bash
./src/autorotate.sh
```

## How It Works

1. **Configuration** – `src/autorotate.sh` sources `config/config.conf` to
   read the display name and log path.
2. **Library** – The rotation logic lives in `lib/rotate.sh` and is sourced by
   the main script.
3. **Sensor monitoring** – `monitor-sensor` (from `iio-sensor-proxy`) is
   started and its output is appended to the log file.
4. **Log watching** – `inotifywait` watches the log file for changes.
5. **Screen rotation** – When an orientation change is detected, `rotate()` is
   called, which:
   - Uses `xrandr` to rotate the display.
   - Uses `xinput --list --id-only` to discover all input devices and remaps
     each one to the rotated display.

## Customization

| Setting   | File                 | Description                                  |
|-----------|----------------------|----------------------------------------------|
| `DNAME`   | `config/config.conf` | Display name (e.g. `eDP-1`). Find with `xrandr`. |
| `LOG`     | `config/config.conf` | Path to the sensor log file.                 |
| `DISPLAY` | `config/config.conf` | X display (default `:0`).                    |

## Troubleshooting

- **No rotation detected** – Ensure `iio-sensor-proxy` is running and test
  with `monitor-sensor` directly.
- **Wrong display name** – Run `xrandr` and set `DNAME` in
  `config/config.conf`.
- **Touchscreen not remapped** – Run `xinput --list` to verify your device is
  listed and that `xinput map-to-output` works for it.

## License

MIT License

## Acknowledgments

- Original method inspired by
  [linuxappfinder.com](https://linuxappfinder.com/blog/auto_screen_rotation_in_ubuntu)
- Thanks to the open-source community and
  [@Links2004](https://github.com/Links2004) for inspiration!
