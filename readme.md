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

To remove everything again: `./sticky uninstall` — stops and deletes the four services. Notes, wallpapers and the log are kept.

## Usage

Everything goes through one command: `./sticky <command>` (see `./sticky help`).

- **Add/edit a note:** save a file in `~/Desktop/Sticky` or any of its subdirectories; wallpaper re-renders within a second (`serve` watcher).
- **Group notes:** put them in a subdirectory (`~/Desktop/Sticky/work/`) — the folder name is prefixed to the card heading.
- **Markdown notes:** save `.md`/`.markdown`. The card header is the file's own main `#` heading (ATX `# ` or setext `===` title) with a thin divider under it — the filename is not used, and the title is not repeated in the body. Files without a top-level heading render as a plain headerless markdown preview. Everything inside renders like a VS Code preview: ATX/setext headings, **bold**, *italic*, ***both***, ~~strikethrough~~, `inline code`, [links](url) and autolinks, images (as alt text), bullet/ordered/nested lists, `- [x]` task checkboxes, blockquotes (incl. nested), fenced code blocks (``` or ~~~, no inline styling inside), `---` rules and tables (monospace, aligned). Long files still split into `(1/N)` cards, and a title-only file renders as a header-only card. Falls back to plain text if ImageMagick lacks the Pango coder.
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
- `serve` keeps one render in flight at most: before every render it checks for a running one and gracefully stops it (SIGTERM to the render job's process group; the job removes its temp dir and exits), then renders with the latest note contents. Rapid saves collapse into a single final render instead of a queue.




![Sticky notes wallpaper example](/logs/Sticky.png)









## How it works

Two modes for the COSMIC background:

- **Sticky** — a random slideshow image with your notes rendered on top.
- **Normal** — a clean random slideshow image.

| Service | Trigger | Action |
|---|---|---|
| `notify.service` (`sticky serve`) | file saved (`close_write`) in `~/Desktop/Sticky` or its subdirectories | Stops any in-flight render, then re-renders notes onto a new random wallpaper with the latest notes, applies it |
| `session_state.service` | started with `graphical-session.target`, stopped at logout | Last rendered sticky image on login (`ExecStart`), clean wallpaper on logout (`ExecStopPost`) |
| `lockscreen_watcher.service` (`sticky watch-lock`) | logind events via `gdbus` while logged in | Clean wallpaper on lock, suspend and shutdown/reboot |

Login and logout are detected by systemd itself (`session_state.service` starts and stops with the graphical session), so they work even though the other services are killed with the session at logout; shutdown/reboot are covered both by the watcher (`PrepareForShutdown`) and by `ExecStopPost` at teardown.

The login screen is a separate system greeter (`cosmic-greeter` via greetd). Its wallpaper comes from the greeter daemon, which keeps its own persisted copy of the last-login background **source path** — it does not follow live config changes. That is why on/off never edit the config's `source:` line: the config always points at `Target/Sticky.png` and on/off atomically swap that **file's content** instead (clean image for off, rendered notes for on). Whatever path the greeter captured, it renders a file whose content always matches the current mode, so the login screen is clean at logout, at boot after shutdown/reboot, and notes appear right after login. As extra insurance, `sticky on` also checks logind and only applies when a real (non-greeter) session is active.

`serve` and `watch-lock` are fully independent — each runs in its own service, so a note edit re-renders even outside a login event, and lock/suspend/shutdown switching never blocks note watching.

## How the wallpaper refresh works (no restart)

On and off never change the config's `source:` — it always points at `Target/Sticky.png` and the rendered notes live in `Target/notes.png`. Applying a mode copies the right file over a temp name and atomically `mv`s it onto `Target/Sticky.png` (the greeter's persisted source path always resolves to the current content this way).

`cosmic-bg` re-renders on any change to the config it actually watches, but it ignores a write whose parsed content is unchanged, which would freeze note edits (same config, new PNG). So the scripts bump `rotation_frequency` on every apply. The value is meaningless for single-image sources, but the difference forces `cosmic-bg` to reload and crossfade to the freshly swapped PNG. It always increases so even two applies that arrive almost at once cannot cancel each other out.

Since cosmic-bg 1.11 the background config is per theme mode: the live file is `~/.config/cosmic/com.system76.CosmicBackground.Dark/v1/all` or `...Light/v1/all` (chosen by `com.system76.CosmicTheme.Mode/v1/is_dark`), while `~/.config/cosmic/com.system76.CosmicBackground/v1/all` is only a legacy/shared seed. Writing only the legacy file leaves the wallpaper frozen after an update. Sticky writes the template to the legacy file **and both** mode files, so whichever theme is active reloads and switching themes later cannot break it.

Each config is written atomically: `sed` renders the template into a `.atomicwrite-*` temp file inside the config dir, then `mv` swaps it into place — mirroring how COSMIC itself writes configs, so the watcher fires exactly once with complete content. `cosmic-bg` is never killed — sticky only edits its config files, and `cosmic-bg` itself is started and owned by the COSMIC session.

## How rapid note saves are handled (one render at a time)

Every render runs as a detached job in its own process group, tracked by a pid file (`wallpapers/Target/.render.pid`). When a note is saved while a render is still running, `serve` first sends SIGTERM to that whole group — the job's trap removes its temp dir and exits, and `serve` waits until it is really dead — then starts a fresh render that reads the latest note contents. The last save always wins; nothing is queued.

This is safe by construction: the rendered image is composed in a private temp dir and published with a single atomic `mv`, and the cosmic config is written temp-file-then-`mv` as well. A canceled render therefore can never leave a half-written wallpaper image or config behind, and two renders can never interleave their output.

## Files

| File | Purpose |
|---|---|
| `sticky` | The single command: `install`, `uninstall`, `status`, `on`, `off`, `render`, `refresh`, `serve`, `watch-lock`, `log`. Includes the renderer — `.md` cards use the file's own `#` heading as the card title (headerless when there is none), `.txt` cards use the filename, long files split into `(1/N)` cards, cards stack down the right edge. |
| `services/` | systemd user unit templates (`notify.service`, `session_state.service`, `lockscreen_watcher.service`) — full paths baked in by `sticky install`. |
| `setting_conf/` | COSMIC background config templates (`normal`, `sticky`). |
| `wallpapers/Slideshow/` | Pool of background images (`0.jpg`, `1.jpg`, ...). |
| `wallpapers/Target/` | Generated images (`Sticky.png`, `normal.png`). |
| `logs/lock.log` | Watcher event log. |
