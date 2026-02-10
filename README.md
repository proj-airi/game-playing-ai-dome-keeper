# AIRI Dome Keeper Plugin

## YOLO Data Collector Mod Development Requirements

### Clone repository and install dependencies

```bash
git clone https://github.com/AIRI-Dome-Keeper/airi-dome-keeper.git
cd airi-dome-keeper
bun install
```

### Decompile the game

**Please follow the [rules](https://github.com/DomeKeeperMods/Docs/wiki/Getting-Started#modding-intro-and-rules) in the modding docs.**

**We assume you already bought and installed this game.**

Download the GDRETools from [here](https://github.com/GDRETools/gdsdecomp/releases).

Set the environment variables (You can use `direnv` to keep these environment variables scoped to this repo):

```bash
export DOMEKEEPER_GAME_DIR="/path/to/Dome Keeper"
export GODOT_BIN="/path/to/Godot"
export GDRETOOLS_BIN="/path/to/gdre_tools"
export DOMEKEEPER_VERSION="4.2.2"
```

Or PowerShell:

```powershell
$env:DOMEKEEPER_GAME_DIR = "C:\Path\To\Dome Keeper"
$env:GODOT_BIN = "C:\Path\To\Godot.exe"
$env:GDRETOOLS_BIN = "C:\Path\To\gdre_tools"
$env:DOMEKEEPER_VERSION = "4.2.2"
```

Then run the following command to decompile the game:

```bash
bun run decompile
```

### Open the Decompiled Project with Godot

```bash
bun run godot:open
```
