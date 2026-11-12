#!/usr/bin/env python3
"""Stage a SpriteKiln prototype spec in an isolated GitHub Actions workspace.

No game assets are changed or committed. Preview outputs remain workflow artifacts.
"""
import argparse
import re
import shutil
import subprocess
from pathlib import Path

SAFE_SPEC = re.compile(
    r"^godot/art/specs/characters/([a-z][a-z0-9_-]{0,39})/([a-z][a-z0-9_-]{0,39})\.ya?ml$"
)

def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo-root", type=Path, required=True)
    parser.add_argument("--workspace", type=Path, required=True)
    parser.add_argument("--spec-path", default="")
    args = parser.parse_args()

    repo = args.repo_root.resolve(strict=True)
    workspace = args.workspace.resolve(strict=True)
    request = args.spec_path.strip()
    if request:
        match = SAFE_SPEC.fullmatch(request)
        if not match or match.group(1) != match.group(2):
            parser.error(
                "spec_path must be godot/art/specs/characters/<name>/<name>.yaml "
                "(lowercase letters, numbers, underscores, or hyphens; matching names)"
            )
        source = (repo / request).resolve(strict=True)
        if not source.is_relative_to(repo / "godot" / "art" / "specs" / "characters"):
            parser.error("spec_path must remain inside the character spec directory")
        if source.stat().st_size > 512_000:
            parser.error("Character specification is too large")
        selected = Path("art/specs/characters") / match.group(1) / source.name
        destination = workspace / selected
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, destination)
    else:
        subprocess.run(
            ["spritekiln", "new", "prototype_scout"],
            cwd=workspace,
            check=True,
        )
        selected = Path("art/specs/characters/prototype_scout/prototype_scout.yaml")
        if not (workspace / selected).is_file():
            parser.error("SpriteKiln did not create the expected sample spec")
    (workspace / "selected_spec.txt").write_text(str(selected) + "\n", encoding="utf-8")
    print(f"Selected SpriteKiln specification: {selected}")
    print("PREVIEW ONLY: artifacts will not be committed to the Hollowmark repository.")

if __name__ == "__main__":
    main()
