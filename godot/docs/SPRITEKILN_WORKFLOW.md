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


## ChatGPT reference-image workflow (automated previews, added 2026-11-12)
- The user can upload a reference image to ChatGPT. ChatGPT describes the visual traits and creates/updates `godot/art/specs/characters/<name>/<name>.yaml` on `claude/godot-port`. The file is an editable **procedural approximation** of the reference, not an automatic exact image-to-model conversion.
- A separate workflow on this branch, `.github/workflows/spritekiln-auto-preview.yml`, watches **changes to YAML character specs**, renders them with SpriteKiln 0.4.0, and uploads reviewable preview+Godot-export artifacts. There is no manual **Run workflow** click after a spec is committed.
- Implementation: `godot/tools/spritekiln/render_changed_specs.py` detects added/modified specs between the pushed commit and previous commit, validates each file in a temporary Godot project, creates eight-direction poses, renders clips, and uploads per-character outputs. It does not update approved game art, import to `AnimatedSprite3D`, or push generated sprites.
- The ChatGPT-uploaded reference image is **not automatically saved to GitHub**. The YAML contains a design description from the reference; for reliable comparison against the original image across agents or future sessions, the owner should separately supply an authorized reference file to the repo (or attach again). Do not pretend that the YAML recreates every hair strand, armor trim, or cape detail.
- First character: `godot/art/specs/characters/lyla/lyla.yaml`, modeled from the user-provided five-view Lyla turnaround. The immediate proof-of-concept test is the automatically launched GitHub Actions run. Iterate on her appearance only after reviewing the contact sheets, respecting the existing art and world-facing direction conventions.


## Verified Lyla proof of concept (2026-11-12)
- Automated spec-on-push workflow was verified: first run https://github.com/JoelsCodes/Tactics-game/actions/runs/43309878209 succeeded with 176 rendered frames, 8 directions, idle/walk/attack, and SpriteKiln QA 0 errors / 0 warnings.
- A second push refined the model's hair and cape and removed the sword; https://github.com/JoelsCodes/Tactics-game/actions/runs/43310324438 also completed successfully and uploaded a 23-file artifact.
- **Visual review:** the procedural preview remains notably more simplified than the owner's five-view reference, especially the anime face, hair volume/curvature, burgundy bow, ornate segmented armor and ragged cape. It is a rendering pipeline proof, NOT owner-approved game art or a faithful match.
- Do not replace Lyla's original art, import into live battle, or claim production quality solely from automated QA. Evaluate at actual battle size and request owner approval after further art-direction improvements.


## Lyla high-detail fidelity experiment (2026-11-12)
- Commit `3d64f3172069e40be999d77e293eeb109dd1fb40` updates `godot/art/specs/characters/lyla/lyla.yaml` with increased image density (`camera.scale: 0.028`), bespoke peach hair ramps and layered ponytail pieces, segmented armor, gold trim, ribbon, tabard, and a shell cape. Automatic GitHub Actions preview run: https://github.com/JoelsCodes/Tactics-game/actions/runs/43311562826 (successful). The preceding commit attempted a two-point tube for boot trim and failed validation; it has been corrected.
- **Visual verdict:** Despite the successful 8-direction animation export and added geometric detail, SpriteKiln's procedural SDF result **still does not faithfully reproduce** the reference illustration's face, ornate armor, hair flow and cape. Do not call this a final/approved match.
- An alternative **reference-derived five-pose turnaround** was cropped from the owner's original five-view illustration, aligned on transparent 128x128 frames, as an offline example (S, SE, E, NE, N); it retains the artwork's visual identity substantially better than the procedural approximation. It is a **five-pose master only**; no walk/attack/cast animations or independent NW/W/SW art have been produced from it, and it has not been added to the repository. Do not silently mirror directions and claim eight hand-authored views.
- For named characters where fidelity matters more than procedural uniformity, prefer a **hybrid image-first workflow**: approved reference -> extract true directions into masters -> approve actual gameplay scale -> create the remaining three directions consistent with approved art -> animate from those masters with strict frame/identity QA -> import through Hollowmark's established AnimatedSprite3D pipeline. SpriteKiln can remain a candidate for rigid/procedural equipment, simple enemies, and animation timing, rather than being the sole renderer for intricately hand-illustrated heroes.
