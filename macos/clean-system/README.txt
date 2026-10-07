CLEAN-SYSTEM-MACOS
==================

Script to free disk space on macOS by deleting only regenerable things:
caches, logs, Trash, installer leftovers and unused Docker data.

Files:
  clean-system.sh   the script
  README.txt        this guide


BASIC COMMANDS
--------------
Go to the folder:
  cd ~/workspace/workspace-utils/shell-utils/macos/clean-system

First time (make executable):
  chmod +x clean-system.sh

1) Preview (deletes nothing, shows how much would be freed):
  ./clean-system.sh

2) Interactive cleanup (asks for confirmation for each group):
  ./clean-system.sh --apply

3) Automatic cleanup (no questions):
  ./clean-system.sh --apply --yes

4) Help:
  ./clean-system.sh -h
  ./clean-system.sh --help

Extra options (combine with --apply):
  --projects        also delete .venv and node_modules in ~/workspace
                    (folder changeable: WORKSPACE=/other/path ./clean-system.sh --projects)
                    Skips projects without requirements.txt/pyproject.toml/
                    Pipfile/setup.py or package.json (not rebuildable).
                    Does not touch .env files. Recreate with:
                      python3 -m venv .venv && source .venv/bin/activate && pip install -r requirements.txt
                      npm install
  --gradle          also delete ~/.gradle/caches (re-downloaded later, slow)
  --docker-volumes  Docker prune also volumes (may lose data!)

Tip: always run the preview first.


WHAT IT CLEANS
--------------
- Trash (~/.Trash)
- User logs (~/Library/Logs)
- Caches for JetBrains, Playwright, Google/Chrome, Firefox, pip, virtualenv,
  node-gyp, typescript, draw.io, VS Code, npm
- Docker Desktop installer leftovers
- Android emulator RAM snapshots (regenerated)
- Homebrew: brew cleanup -s --prune=all
- Go build cache: go clean -cache
- pip cache: pip3 cache purge
- Docker: docker system prune -a  (unused images, stopped containers, unused
  networks). Requires Docker Desktop running, otherwise skipped.

After cleanup, apps rebuild their caches on their own: the first launch may
be a bit slower (e.g. IntelliJ re-indexes).


WHAT IT NEVER TOUCHES
---------------------
- ~/Library/Preferences (app and macOS settings)
- ~/Library/Application Support (JetBrains, Firefox, etc. config)
- ~/Library/Keychains, LaunchAgents, /var/folders
- Personal files and projects

So after a restart you do NOT need to reset preferences or settings.

WARNING: do not use the old ~/workspace/clean-system.sh. It runs
"rm -rf ~/Library/Preferences/*" and "rm -rf /var/folders/": it deletes all
preferences and breaks running apps.


MANUAL CANDIDATES (the script lists them but does NOT delete them)
------------------------------------------------------------------
- Ollama models (~/.ollama, ~31 GB, the biggest):
    ollama list
    ollama rm <model-name>
- Android emulators (~/.android/avd): Android Studio > Device Manager
- Android SDK: SDK Manager, remove old system images/versions
- JetBrains config of old IDE versions in
  ~/Library/Application Support/JetBrains
- .venv / node_modules / target of idle projects (they get recreated):
    rm -rf <project>/.venv   then pip install ...
- WhatsApp/Telegram: from the app settings


WHY "SYSTEM DATA" AND "DOCUMENTS" TAKE SO MUCH SPACE
----------------------------------------------------
System Settings > General > Storage.
- "System Data" includes ~/Library/Caches, Application Support,
  Docker.raw, logs, swap, Time Machine snapshots.
- "Documents" also includes hidden folders in the home directory:
  .ollama, .android, .gradle, .npm, .sdkman, .rustup, workspace.

To check where the space goes:
  du -shx ~/* ~/.[!.]* 2>/dev/null | sort -rh | head -20
  du -sh ~/Library/* | sort -rh | head
  tmutil listlocalsnapshots /                  (Time Machine snapshots)
  sudo tmutil thinlocalsnapshots / 99999999999 4   (free snapshots)
  docker system df                             (Docker space)


TROUBLESHOOTING
---------------
- "Docker installed but daemon not running": open Docker Desktop, run again.
- "Operation not permitted" on some folders: System Settings >
  Privacy & Security > Full Disk Access > enable Terminal.
- Script does not run: chmod +x clean-system.sh
