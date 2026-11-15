# Sticky Notes Wallpaper

Turns your COSMIC wallpaper or any into a live sticky-note board. `.txt` files in `~/Desktop/Sticky` (and its subdirectories) are rendered as glass cards on the wallpaper — a subdirectory name becomes part of the card heading (`work/bugs.txt` → `WORK / BUGS`). On lock/suspend/shutdown/logout the wallpaper switches to a clean one, and back to sticky on login.
## main highlight of this tool is :- 
   -  it's fully automatic when you change notes `.txt` file `~/Desktop/Sticky/` (subdirectories included) after closing write then automatic refresh notes on wallpaper .
   -  subdirectories of `~/Desktop/Sticky/` are rendered too — notes are grouped per folder and the folder name shows in the heading (`~/Desktop/Sticky/work/bugs.txt` → heading `WORK / BUGS`).
   -  only visible sticky notes after login on poweroff/logout/suspend/lockscreen mean you close session its automatic goes normal walpaper. you can also change mode by `./sticky on` and `./sticky off`



![Sticky notes wallpaper example](wallpapers/Target/Sticky.png)


## Dependencies

```bash
# Arch
sudo pacman -S imagemagick inotify-tools

# Debian/Ubuntu
sudo apt install imagemagick inotify-tools
```

- ImageMagick — `magick`/`convert`, used by the renderer. If your build includes the Pango coder (Ubuntu/Debian and most distros do), `.md` notes render as a markdown preview; otherwise they fall back to plain text.
- inotify-tools — `inotifywait`, used by the note watcher
- COSMIC desktop — `cosmic-bg` and `gdbus`, already part of COSMIC
- systemd — runs the user services

## Setup

No hardcoded paths needed — the script auto-detects the repo location, and `install` bakes the absolute path into the systemd units (services require full paths everywhere).

1. Add numbered images to `wallpapers/Slideshow/`.

2.
   ```bash
   mkdir -p ~/Desktop/Sticky
   ```
   Creates the notes folder the watcher monitors (setup does this too).

3.
   ```bash
   ./sticky install
   ```
   Renders `services/*.service` from the current directory, writes the absolute path into `ExecStart`, installs them to `~/.config/systemd/user/`, then enables and restarts them. Rerun it whenever you move the repo so the service paths get updated.

To remove everything again: `./sticky uninstall` — stops and deletes the three services. Notes, wallpapers and the log are kept.

## Usage

Everything goes through one command: `./sticky <command>` (see `./sticky help`).

- **Add/edit a note:** save a file in `~/Desktop/Sticky` or any of its subdirectories; wallpaper re-renders within a second (`serve` watcher).
- **Group notes:** put them in a subdirectory (`~/Desktop/Sticky/work/`) — the folder name is prefixed to the card heading.
- **Markdown notes:** save `.md`/`.markdown` and the card renders like a VS Code markdown preview — headings, **bold**, *italic*, `code`, ~~strikethrough~~, links, bullet/ordered lists, blockquotes, fenced code blocks and `---` rules. Long files still split into `(1/N)` cards.
- **Remove a note:** delete the file, then touch any remaining note to re-render.
- **Render only (no apply):** `./sticky render` — random image; or pick one: `./sticky render wallpapers/Slideshow/3.jpg`
- **Render + apply in one step:** `./sticky refresh`
- **Show last rendered sticky image (no render):** `./sticky on`
- **Clean wallpaper, no notes (no render):** `./sticky off`
- **Status overview:** `./sticky status`
- **Watch the log:** `./sticky log`
- **Remove the services:** `./sticky uninstall`

## Notes

- The script resolves its own directory at runtime (`SCRIPT_DIR`) — the repo can live anywhere.
- The systemd units get the absolute path baked in by `./sticky install`; rerun it after moving the repo.
- `serve` reacts to `close_write` events only — save complete files (editors do this); partial/streamed writes are ignored. It watches the notes folder recursively, so subdirectories are covered too.




![Sticky notes wallpaper example](/logs/Sticky.png)









## How it works

Two modes for the COSMIC background:

- **Sticky** — a random slideshow image with your notes rendered on top.
- **Normal** — a clean random slideshow image.

| Service | Trigger | Action |
|---|---|---|
| `notify.service` (`sticky serve`) | file saved (`close_write`) in `~/Desktop/Sticky` or its subdirectories | Re-render notes onto a new random wallpaper, apply it |
| `lockscreen_watcher.service` (`sticky watch-lock`) | logind events via `gdbus` | Clean wallpaper on lock/suspend/shutdown/logout; last rendered sticky image on login |
| `restart_bg.service` | runs continuously | Safety net — restarts `cosmic-bg` only if it ever crashes (normal refresh never kills it) |

`serve` and `watch-lock` are fully independent — each runs in its own service, so a note edit re-renders even outside a login event, and lock/logout switching never blocks note watching.

## How the wallpaper refresh works (no restart)

`cosmic-bg` watches `~/.config/cosmic/com.system76.CosmicBackground/v1/all` with inotify and re-renders on any config change — but it ignores a write whose parsed content is unchanged, which would freeze note edits (same config, new PNG). So the scripts flip `rotation_frequency` between `300` and `301` on every apply. The value is meaningless for single-image sources, but the difference forces `cosmic-bg` to reload and crossfade to the freshly rendered PNG.

The config is written atomically: `sed` renders the template into a `.atomicwrite-*` temp file inside the config dir, then `mv` swaps it into place — mirroring how COSMIC itself writes configs, so the watcher fires exactly once with complete content. `cosmic-bg` is never killed; `restart_bg.service` only rescues it if it crashes.

## Files

| File | Purpose |
|---|---|
| `sticky` | The single command: `install`, `uninstall`, `status`, `on`, `off`, `render`, `refresh`, `serve`, `watch-lock`, `log`. Includes the renderer — filename → mint heading, `.md` → markdown preview (via the Pango coder), long files split into `(1/N)` cards, cards stack down the right edge. |
| `services/` | systemd user unit templates (`notify.service`, `lockscreen_watcher.service`, `restart_bg.service`) — full paths baked in by `sticky install`. |
| `setting_conf/` | COSMIC background config templates (`normal`, `sticky`). |
| `wallpapers/Slideshow/` | Pool of background images (`0.jpg`, `1.jpg`, ...). |
| `wallpapers/Target/` | Generated images (`Sticky.png`, `normal.png`). |
| `logs/lock.log` | Watcher event log. |
