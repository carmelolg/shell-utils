# make-bootable

Interactive wizard that writes an ISO image to an external USB drive, producing bootable installation media. macOS only.

Part of [shell-utils](../../README.md).

## Requirements

- macOS (the script exits on Linux and other systems)
- `sudo` access (the write uses `dd` on the raw device)
- Full Disk Access for Terminal, if macOS asks for it (see Troubleshooting)
- A physical external USB drive

## Usage

```bash
# Pick the ISO interactively
./make-bootable.sh

# Or pass the ISO path directly
./make-bootable.sh ~/Downloads/xubuntu-26.04-desktop-amd64.iso

# Help
./make-bootable.sh -h
```

Or use the alias defined in `~/.zshrc`:

```bash
make-bootable
```

## How It Works

1. **ISO selection** – if no path is given, lists `*.iso` files in `~/Downloads`, newest first, with their sizes. You can also type a different path. A leading `~` is expanded.
2. **Disk selection** – lists only external physical disks (`diskutil list external physical`) with name, size and partition count. Internal disks are never offered.
3. **Compatibility check** – aborts if the ISO is larger than the selected disk.
4. **Confirmation** – shows a summary and asks you to type the disk identifier (for example `disk4`) to confirm. Any other input cancels.
5. **Write** – unmounts the disk, then runs `sudo dd` from the ISO to the raw device (`/dev/rdiskN`, `bs=4m`). Uses `status=progress` when the system `dd` supports it.
6. **Finish** – `sync`, then ejects the disk.

## Warnings

- **Everything on the selected disk is erased, and this cannot be undone.**
- The disk is chosen by number from the list. Check the name and size before confirming.

## Troubleshooting

**`Operation not permitted` during the write**

1. Open **System Settings**.
2. Go to **Privacy & Security**.
3. Select **Full Disk Access**.
4. Enable **Terminal** (or your terminal app).
5. Restart the terminal and run the script again.

**No external disk found**

Connect the USB drive and run the script again. Internal disks and disk images are excluded on purpose.

**Progress not visible**

If the system `dd` does not support `status=progress`, press `Ctrl+T` during the write to print the current status.
