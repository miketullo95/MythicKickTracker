# MythicKickTracker

A Mythic+ interrupt assignment addon for World of Warcraft (Retail).

Focus a mob — it's assigned to you. Your chosen raid marker gets stamped on it automatically, an alert fires when it casts something interruptible, and a live panel shows the whole group's kick assignments before the key starts.

---

## Features

- **Focus = Assigned** — the moment you focus a non-player unit, it becomes your kick target and gets marked with your chosen raid icon
- **Custom cast bar** — a movable, resizable, colour-configurable bar that appears only for interruptible casts (optional: show all casts)
- **Alert sound** — plays when your focus target begins an interruptible cast (TTS "Kick", bundled sound, WoW UI sounds, or a custom file)
- **Pre-key panel** — auto-opens when you zone into a M+ dungeon, showing each group member who has the addon, their marker, and their assigned mob
- **Marker conflict warnings** — if two players pick the same marker, their rows highlight red with a warning icon
- **Party sync** — assignments and marker choices are broadcast to other players who have the addon installed
- **Auto-announce** — when you pick your marker, it's automatically announced to party chat (e.g. `My kick marker is [Square] — watch for my interrupts!`)
- **Dev test mode** — test everything without being in a dungeon (`/kt test`)

---

## Installation

### Via CurseForge / Wago App (recommended)
Search for **TulloKickTracker** in the CurseForge or Wago app and click Install.

### Manual
1. Download the latest release `.zip` from the [Releases](../../releases) page
2. Extract it so that `TulloKickTracker/` sits inside your WoW AddOns folder:
   ```
   World of Warcraft/_retail_/Interface/AddOns/TulloKickTracker/
   ```
3. Reload your UI in-game (`/reload`)

---

## Usage

| Command | What it does |
|---|---|
| `/kt` or `/kicktracker` | Show help |
| `/kt panel` | Toggle the assignment panel |
| `/kt config` | Open settings |
| `/kt announce` | Manually announce your marker to party chat |
| `/kt test` | Toggle dev test mode (fake party, no dungeon needed) |
| `/kt testsound` | Play your alert sound immediately |
| `/kt testcast` | Show a fake 3-second interruptible cast bar |
| `/kt testpanel` | Force open the panel regardless of location |
| `/kt testconflict` | Simulate a marker conflict warning in the panel |

---

## Settings (`/kt config`)

- **My Kick Marker** — choose which of the 8 raid icons is yours
- **Active In** — Mythic+ only (default) or all dungeons
- **Auto-Announce Marker** — broadcast to party chat when you pick/change your marker
- **Keep Panel Visible During Combat** — off by default
- **Alert Sound** — TTS / bundled / WoW UI sound / custom path
- **Cast Bar** — show all casts or interruptible only; width, height, colour per cast type

---

## For Developers

### Local setup
1. Clone the repo into your WoW AddOns directory:
   ```bash
   git clone https://github.com/YOUR_USERNAME/TulloKickTracker.git
   ```
2. Download [Ace3](https://www.curseforge.com/wow/addons/ace3) and place the library folders inside `Libs/` (the packager handles this automatically on release builds, but you need them locally to run the addon)
3. Reload your UI after any code changes: `/reload`

### Recommended debug addons
- **ViragDevTool** — inspect frames, tables, and events live (`/vdt`)
- **BugSack + BugGrabber** — catches and displays Lua errors

### Releasing
Releases are handled automatically via GitHub Actions (see `.github/workflows/release.yml`). To publish a new version:
1. Update the version number in `TulloKickTracker.toc`
2. Commit and push
3. Create a git tag: `git tag v1.0.1 && git push --tags`

The workflow will build the zip (with Ace3 embedded), then push to CurseForge and Wago.io simultaneously.

---

## License

MIT — see [LICENSE](LICENSE)
