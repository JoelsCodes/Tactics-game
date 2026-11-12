# SpriteKiln sprite factory — ChatGPT ↔ GitHub Actions ↔ Hollowmark
Added 2026-11-12. This integration is a **manual, artifact-only preview generator**, not an automatic replacement of approved game art.

## What has been configured
- A GitHub Actions `workflow_dispatch` workflow exists on the repository's **default `main` branch**: [SpriteKiln - Generate Sprite Preview](https://github.com/JoelsCodes/Tactics-game/actions/workflows/spritekiln-preview.yml). The workflow explicitly checks out `claude/godot-port` for current Hollowmark sources.
- It installs the SpriteKiln Python CLI, creates an **isolated temporary Godot workspace**, and either generates a template sample `prototype_scout` or copies an explicitly selected YAML spec checked into `claude/godot-port`.
- It validates, optionally creates an 8-direction pose preview, renders and exports, then uploads generated files as a 14-day GitHub Actions artifact.
- It has `contents: read` permissions, does not push, does not modify the game branch, and does not import generated art into Hollowmark. Inspect and approve renders before any import.
- The preparation helper is `godot/tools/spritekiln/prepare_preview.py`. It restricts requested source paths to `godot/art/specs/characters/<name>/<name>.yaml`.

## Manual first run (desktop or mobile GitHub browser)
1. Open [Actions → SpriteKiln - Generate Sprite Preview](https://github.com/JoelsCodes/Tactics-game/actions/workflows/spritekiln-preview.yml) while signed in with access to Actions.
2. Press **Run workflow**. Select the **main** branch in the workflow dispatcher (the workflow definition is on main); this workflow itself checks out Hollowmark's `claude/godot-port`.
3. Leave `spec_path` empty for the safe template proof of concept; keep `include_pose_preview` enabled.
4. After the job finishes, open its run page and download the **spritekiln-preview-<run-id>** artifact. It should contain poses/previews and Godot export resources under `specs/` and `exports/`.
5. Compare the output against the approved game art. **Do not** overwrite `alaric_v2`, `assets/characters/`, or `meta.json` without owner approval and a specific conversion/import test.

## Creating a new original character spec through ChatGPT
- Ask ChatGPT to build a SpriteKiln YAML definition based on an approved character description or reference.
- Store it through GitHub in `godot/art/specs/characters/<name>/<name>.yaml` on `claude/godot-port`, using a lowercase ASCII name (1–40 chars; letters, digits, underscores and hyphens; start with a letter).
- Start the workflow with the literal `spec_path` `godot/art/specs/characters/<name>/<name>.yaml`. YAML should not depend on undeclared sibling files or assets: the preview currently stages just the chosen YAML.
- After visual approval, implement a separate conversion/validation stage to translate SpriteKiln's output into Hollowmark's `SpriteAnimator`, `meta.json` and `AnimatedSprite3D` formats. The standard SpriteKiln Godot exporter makes `Sprite2D`/KilnSprite2D resources, **not** Hollowmark-ready 3D unit views.

## Existing game art standard
- Preserve owner's existing 128×128 RGBA cells, true transparent backgrounds, nearest-neighbor pixel sharpness, feet pivot and alignment, original direction order **S, SE, E, NE, N, NW, W, SW**, correct poses, and approved character identity.
- For Alaric the production source is `godot/tools/art/alaric_v2.py`, with 8D sprites and custom attack/cast/hit/KO. No replacement without explicit review.
- Current ingestion code: `godot/tools/art/eight_dir.py`, `godot/tools/art/test_eight_dir.py`, `godot/tools/build_resources.gd`, `godot/scripts/stage/sprite_animator.gd`, and `godot/scripts/stage/unit_view_3d.gd`.
- SpriteKiln uses 3D procedural shapes. It may render multi-direction animations consistently, but matching a highly detailed hand-drawn design is **not guaranteed**. Character-identity approval comes before mass animation production.

## First-run limitations and troubleshooting
- This is a newly authored CI configuration; a completed SpriteKiln render has **not been verified yet**. Check the first run's logs and correct CLI version flags or output paths if needed.
- Manual workflow runs must be launched through GitHub Actions; the current ChatGPT GitHub connection can edit the repository, but does **not** expose a workflow-dispatch action. ChatGPT can create specs and review repo files; it cannot currently push a Run workflow button through this connector.
- Current runner resolves `spritekiln[fast]>=0.4,<0.5` from Python package index. Upstream versions can change; after a successful test, pin the verified version and hash/dependency lock as appropriate.
- The workflow has a 35-minute job timeout and 14-day artifact retention; preview cost is GitHub Actions compute minutes.
- The workflow on default `main` is a minimal runner; source code/specs are read from `claude/godot-port`. Do not accidentally copy unapproved game art into main.
- For MCP-based local use, upstream recommends `spritekiln init --engine godot --ai claude`; GitHub Actions can run the CLI unattended, without an interactive MCP session.
- Sources: https://github.com/LucasJRamos/spritekiln and https://github.com/LucasJRamos/spritekiln/blob/main/docs/engines/godot.md

## Next milestone
Successfully render the neutral template, inspect the artifact, then create an original approved Hollowmark character specification and measure style fidelity/foot anchoring against our current sprite pipeline. Only afterward build the automatic 3D-game importer.
