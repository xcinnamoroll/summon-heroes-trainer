# Summon Heroes Trainer

An AutoHotkey v2 automation tool for the Roblox game **Summon Heroes**. A compact, always-on-top GUI with Story Mode auto-clicking, per-map Auto Chest pathing, recordable Custom Paths triggered by on-screen images or timers, PvP Shop auto-buy, and an in-app image capture/update workflow. I made this for fun — do not use for malicious purposes or unfair advantages.

![AutoHotkey v2](https://img.shields.io/badge/AutoHotkey-v2.0-green)
![Platform](https://img.shields.io/badge/platform-Windows-blue)
![Status](https://img.shields.io/badge/status-unmaintained-lightgrey)

> **Status: no longer maintained.** The last release is [v1.0.90](https://github.com/xcinnamoroll/summon-heroes-trainer/releases/tag/v1.0.90). The trainer still works as of that version, but no further updates, bug fixes, or compatibility patches are planned. If the in-game UI changes, image-detection-based features (Story Mode, Auto Chest, Custom Pathing triggers, PvP Shop auto-buy) may need re-captured reference images to keep working. Forks welcome.

## Features

### Story Mode

- **Auto Mode** — retries the current stage up to a configured max, then advances by clicking *Next Stage* or *Play Next Map*. Falls back to retry-only if no advance button appears within a grace window.
- **Retry Mode** — just clicks the retry button whenever it appears.
- **Spam Click** — when your mouse goes idle over Roblox, rapidly left-clicks. Pauses the moment you move the mouse, press WASD, or hover the trainer GUI.
- **Teleport to Units** — periodically scans for and clicks the teleport button while idle.
- **Human-like Mouse Movement** — bezier curves with eased acceleration so the cursor doesn't snap.
- Live status panel shows mode, retry count, current phase, and last action.

### Auto Chest

- Per-map loading-image detection for all nine current maps (Rookie Island → Aetherwell Citadel).
- When a map's loading image appears, Auto Chest **arms** the custom path you've assigned to that map. The path's own trigger is what actually starts playback, so you can still chain multiple paths per map by combining triggers.
- Only runs while Story Mode auto/retry is active. Switching maps automatically disarms the previous path.
- Capture or upload each map's loading image directly from the Auto Chest page.

### Custom Pathing

- **Record** sequences of `W A S D E Space` and arrow-key presses with timing. Press **F8** to stop recording. OS auto-repeat is filtered out so paths don't get spammed with duplicate down-events.
- **Two trigger types** per path:
  - **Image** — capture or upload an on-screen image; the path fires when it's detected in Roblox.
  - **Timer** — fires every N seconds.
- **Search regions** — restrict trigger detection to a half/quarter of the Roblox window (whole, top/bottom half, left/right half, or any quadrant). Faster scans and fewer false positives.
- **Arm** multiple paths at once — each fires independently when its trigger matches; only one plays at a time.
- **Play / Stop** for manual single-shot playback.
- **Test Trigger** — single-shot detection check so you can verify a trigger image works before arming.
- **Recapture / Upload / Set Timer / Set Region** — change a saved path's trigger or region without re-recording.
- **Rename / Delete / Import / Export** — `.path` files are self-contained (trigger image is base64-embedded), so they're easy to share.
- Async playback uses absolute deadlines per event, so timing doesn't drift even when the system is busy.
- Auto-releases all held keys on stop, exit, or if Roblox loses focus mid-playback.

### Image Capture

- Dedicated page for capturing the four Story Mode buttons (Retry Stage, Next Stage, Play Next Map, Teleport).
- Per-image search-region dropdown — same options as Custom Pathing triggers.
- "Open Buttons Folder" jumps to the AppData buttons directory.

### Quality of life

- **Update checker** — checks GitHub releases on startup; the sidebar button highlights when a new version is out.
- **Anti-cheat warning** — detects Riot Vanguard / EAC / BattlEye / Faceit on startup and warns that they can silently block PrintWindow capture.
- **Persistent settings** — every toggle, edit field, and Auto Chest map assignment saves to `%AppData%\SummonHeroesTrainer\settings.ini`.
- **Press `Insert`** to minimize/restore the trainer window from anywhere.

## Download

Grab the latest `summon_heroes_trainer.exe` from the [Releases](https://github.com/xcinnamoroll/summon-heroes-trainer/releases) page and run it — no installation required.

## Quick Start

1. Open Roblox and launch **Summon Heroes**.
2. Run `summon_heroes_trainer.exe`.
3. Go to the **Image Capture** tab and capture each Story Mode button (Retry Stage, Next Stage, Play Next Map, Teleport).
4. On the **Story Mode** tab, click **Auto** or **Retry**.
5. Optional — set up Auto Chest:
   - Record a custom path on the **Custom Pathing** tab (press **F8** to stop).
   - On the **Auto Chest** tab, capture each map's loading image and assign a path.
   - Toggle **Auto Chest** on the Story Mode tab.
6. Click **STOP**, move the mouse, or press WASD to pause automation.

## Pages

| Page | Purpose |
| --- | --- |
| **Story Mode** | Auto/Retry/Stop, spam click + teleport toggles, live status panel |
| **Auto Chest** | Per-map loading image + assigned path |
| **Custom Pathing** | Record/play/arm key macros triggered by images or timers |
| **Summon Shop / Item Shop** | Never built |
| **PvP Shop** | Per-item identifier image + click-point offset; spam-clicks each enabled item's Buy button while it's green |
| **Image Capture** | Capture Story Mode button images and set their search regions |

## Settings

Saved to `%AppData%\SummonHeroesTrainer\settings.ini` and persisted across sessions:

| Setting | Default | Description |
| --- | --- | --- |
| Max retries | 9 | Retries before advancing in Auto mode |
| Current retry | 0 | Editable so you can resume mid-run |
| Teleport interval | 5000 ms | How often to look for the teleport button |
| Idle threshold | 1000 ms | How long the mouse must be still before spam clicking / teleporting |
| Spam click interval | 200 ms | Delay between spam clicks |
| Teleport / Spam Click / Auto Chest toggles | on / on / off | Persisted between launches |
| Auto Chest path per map | — | Stored under `[AutoChest]` keyed by map slug |
| PvP Shop auto-buy + click offsets | off / 0,0 | Per-item, stored under `[PvPShop]` keyed by item slug |

## AppData Layout

```text
%AppData%\SummonHeroesTrainer\
├── settings.ini                  Mode, intervals, toggles, per-map path assignments
├── icon.ico, background.png      Extracted on first launch
├── buttons\                      Story Mode capture PNGs (+ optional .region sidecars)
├── auto_chest\                   Per-map loading images (one PNG per map)
├── pvp_shop\                     Bundled PvP Shop card icons (extracted on first launch)
├── pvp_shop_detect\              User-uploaded identifier images for auto-buy
└── paths\                        .path files (key macro + base64 trigger image)
    └── .tmp\                     Decoded trigger images while paths are armed
```

## Hotkeys

| Key | Where | Action |
| --- | --- | --- |
| `Insert` | Anywhere | Minimize / restore the trainer window |
| `F8` | While recording a path | Stop recording |
| `Enter` | Inside a number field | Commit value and unfocus |

## Building from Source

### Requirements

- [AutoHotkey v2.0+](https://www.autohotkey.com/)

### Run from source

```text
AutoHotkey.exe summon_heroes_trainer.ahk
```

### Compile to exe

Run `build.bat` (uses Ahk2Exe at the default install path), or compile `summon_heroes_trainer.ahk` manually with [Ahk2Exe](https://www.autohotkey.com/docs/v2/Scripts.htm#ahk2exe).

## Notes

- The trainer uses `PrintWindow` so it can read Roblox even when partially covered for Story Mode detection. **Custom Pathing triggers** use native `ImageSearch`, which requires Roblox to be visible (not covered) — pathing already requires Roblox to be the active window, so this isn't a practical limitation.
- Kernel-level anti-cheats (Vanguard especially) can silently block `PrintWindow` and make image detection fail with no error. The startup warning will flag this.

## License

This project is provided as-is for personal use.
