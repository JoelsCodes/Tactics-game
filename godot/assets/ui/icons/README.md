# Your command icons

Drop PNGs here to replace the generated command icons in the battle HUD. A file here wins over
`assets/ui/icon_<name>.png` (made by `tools/art/build_ui.py`).

Names: `attack.png`, `abilities.png`, `items.png`, `defend.png`, `summon.png`, `wait.png`, `move.png`
(also used: `defend.png` for the guard shield over a unit).

- Square, transparent background, 128x128 or larger (they are drawn at about 46-56 px at 1080p).
- A pure magenta #FF00FF background also works: run `python3 godot/tools/art/magenta_key.py in.png out.png` first.
- Full color is fine: your icons are drawn as they are (the generated ones are white and tinted gold).
- After adding files: `godot --headless --path godot --import`.

The full-size originals are in `art_src/icons/` (`*_original.png`). `items.png` had a black background
outside its frame; it was cut away by flood-filling from the corners (tolerance 40) and softening the
edge, then scaled to 256x256. `attack.png` came with a transparent background and was only scaled.
