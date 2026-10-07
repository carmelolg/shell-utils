# shell-utils

Personal collection of shell scripts and utilities, grouped by operating system.

## Structure

```
shell-utils/
├── linux/
│   └── screen-autorotate/      # Auto-rotate screen and touch input (accelerometer)
│       ├── config/config.conf
│       ├── lib/rotate.sh
│       ├── src/autorotate.sh
│       ├── install.sh
│       └── README.md
├── macos/
│   ├── clean-system/           # Cache, log, temp and Docker cleanup (clean-system.sh, LEGGIMI.txt)
│   └── make-bootable/          # Build a bootable USB drive from an ISO (make-bootable.sh)
├── LICENSE
└── README.md
```

## Conventions

- One folder per tool, placed under the OS it targets (`linux/` or `macos/`).
- Every tool keeps its own entry point in `src/` (Linux) or at the top of its folder (macOS).
- Scripts use `set -euo pipefail` and resolve paths relative to their own location, never hardcoded.
- Each tool documents itself in its folder: `README.md` (`LEGGIMI.txt` for clean-system).

## Tools

| Tool | OS | Description | Docs |
|------|----|-------------|------|
| [screen-autorotate](linux/screen-autorotate) | Linux | Rotates screen and touch input from accelerometer data | [README](linux/screen-autorotate/README.md) |
| [clean-system](macos/clean-system) | macOS | Safe cleanup of caches, logs, temp files and Docker | [LEGGIMI](macos/clean-system/LEGGIMI.txt) |
| [make-bootable](macos/make-bootable) | macOS | Writes an ISO to an external disk as bootable media | [README](macos/make-bootable/README.md) |

## Shell aliases

Aliases in `~/.zshrc` point into this repo, for example:

```bash
alias clean-system='bash ~/workspace/workspace-utils/shell-utils/macos/clean-system/clean-system.sh "$@"'
```

If the repo moves, update those lines.

## License

See [LICENSE](LICENSE).
