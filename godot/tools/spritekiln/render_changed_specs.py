#!/usr/bin/env python3
"""Preview character specs changed by a GitHub push. Never writes approved game art."""
import argparse
import json
import re
import shutil
import subprocess
import sys
from pathlib import Path

SPEC_RE = re.compile(r"^godot/art/specs/characters/([a-z][a-z0-9_-]{0,39})/\1\.yaml$")
ZERO = "0" * 40


def command(args, cwd=None, capture=False):
    print("+", " ".join(str(x) for x in args), flush=True)
    return subprocess.run(args, cwd=cwd, check=True, text=True,
                          capture_output=capture)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--before", required=True)
    ap.add_argument("--after", required=True)
    ap.add_argument("--output", required=True)
    args = ap.parse_args()
    repo = Path.cwd().resolve()
    output = Path(args.output).resolve()
    output.mkdir(parents=True, exist_ok=True)
    summary = {"before": args.before, "after": args.after, "characters": []}
    failures = 0

    if args.before == ZERO:
        diff = command(["git", "ls-tree", "-r", "--name-only", args.after,
                        "godot/art/specs/characters"], capture=True).stdout
    else:
        diff = command(["git", "diff", "--name-only", "--diff-filter=AM",
                        args.before, args.after, "--",
                        "godot/art/specs/characters"], capture=True).stdout

    specs = sorted(set(p for p in diff.splitlines() if SPEC_RE.fullmatch(p)))
    if not specs:
        summary["message"] = "No new or modified character spec on this push."
        (output / "summary.json").write_text(json.dumps(summary, indent=2))
        return 0

    for source_path in specs:
        name = SPEC_RE.fullmatch(source_path).group(1)
        result = {"character": name, "spec": source_path, "status": "started"}
        summary["characters"].append(result)
        workspace = output / "work" / name
        workspace.mkdir(parents=True, exist_ok=True)
        (workspace / "project.godot").write_text(
            '[application]\nconfig/name="SpriteKiln Character Preview"\n'
        )
        exported = output / "characters" / name
        exported.mkdir(parents=True, exist_ok=True)
        source = repo / source_path
        relative = Path("art/specs/characters") / name / (name + ".yaml")

        try:
            command(["spritekiln", "init", "--engine", "godot", "--ai", "claude"],
                    cwd=workspace)
            staged = workspace / relative
            staged.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, staged)
            # Keep an exact copy of the source for review.
            shutil.copy2(source, exported / (name + ".yaml"))
            command(["spritekiln", "validate", str(relative)], cwd=workspace)
            command(["spritekiln", "pose", str(relative), "--dirs", "all"],
                    cwd=workspace)
            command(["spritekiln", "render", str(relative), "--export"],
                    cwd=workspace)
            result["status"] = "success"
        except (subprocess.CalledProcessError, OSError, ValueError) as err:
            result["status"] = "failed"
            result["error"] = str(err)
            failures += 1
        finally:
            preview_src = workspace / relative.parent / "out"
            if preview_src.is_dir():
                shutil.copytree(preview_src, exported / "previews", dirs_exist_ok=True)
            godot_src = workspace / "assets/spritekiln"
            if godot_src.is_dir():
                shutil.copytree(godot_src, exported / "godot_exports",
                                dirs_exist_ok=True)
            # Avoid including intermediate caches or the temporary workspace in artifacts.
            shutil.rmtree(workspace, ignore_errors=True)

    shutil.rmtree(output / "work", ignore_errors=True)
    (output / "summary.json").write_text(json.dumps(summary, indent=2))
    print(json.dumps(summary, indent=2))
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
